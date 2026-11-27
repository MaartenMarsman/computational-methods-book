# Samplers shared across chapters.
#
# Each chapter that *introduces* a sampler shows its code inline; later
# chapters source this file instead of repeating it. Keep the code here
# identical to the code shown in the chapter that introduces it.
#
# Common interface:  sampler(log_target, init, n_iter, ...)
#   returns list(draws = <tibble: iteration, one column per parameter>,
#                accept_rate = <numeric>)

# --- Chapter 5: random-walk Metropolis (vector version) ----------------------
metropolis <- function(log_target, init, n_iter, step_size, ...) {
  d <- length(init)
  draws <- matrix(NA_real_, nrow = n_iter, ncol = d)
  current <- init
  current_lp <- log_target(current, ...)
  if (!is.finite(current_lp)) stop("log_target() is not finite at init")
  n_accept <- 0

  for (t in seq_len(n_iter)) {
    proposal <- rnorm(d, mean = current, sd = step_size)
    proposal_lp <- log_target(proposal, ...)
    if (is.nan(proposal_lp)) stop("log_target() returned NaN; return -Inf outside the support")
    if (log(runif(1)) < proposal_lp - current_lp) {
      current <- proposal
      current_lp <- proposal_lp
      n_accept <- n_accept + 1
    }
    draws[t, ] <- current
  }

  colnames(draws) <- if (d == 1) "theta" else paste0("theta_", seq_len(d))
  list(
    draws = as_tibble(draws) |> mutate(iteration = seq_len(n_iter), .before = 1),
    accept_rate = n_accept / n_iter
  )
}

# --- Chapter 6: random-walk Metropolis with Robbins-Monro step-size adaptation --
adaptive_metropolis <- function(log_target, init, n_iter, step_size = 1,
                                target_accept = NULL, eta = 0.7,
                                n_adapt = floor(n_iter / 2),
                                step_range = c(1e-6, 1e6), ...) {
  d <- length(init)
  if (is.null(target_accept)) target_accept <- if (d == 1) 0.44 else 0.234
  draws <- matrix(NA_real_, nrow = n_iter, ncol = d)
  step_sizes <- numeric(n_iter)
  accepted <- logical(n_iter)
  current <- init
  current_lp <- log_target(current, ...)
  log_c <- log(step_size)

  for (t in seq_len(n_iter)) {
    proposal <- rnorm(d, mean = current, sd = exp(log_c))   # 1. propose
    proposal_lp <- log_target(proposal, ...)
    log_r <- proposal_lp - current_lp                        # 2. compare
    if (log(runif(1)) < log_r) {                             # 3. accept ...
      current <- proposal
      current_lp <- proposal_lp
      accepted[t] <- TRUE
    }
    draws[t, ] <- current                                    # ... or stay and record
    if (t <= n_adapt) {                                      # 4. Robbins-Monro update
      alpha_t <- exp(min(0, log_r))                          #    alpha_t = min(1, r)
      log_c <- log_c + t^(-eta) * (alpha_t - target_accept)
      log_c <- min(max(log_c, log(step_range[1])), log(step_range[2]))  # keep c in range
    }
    step_sizes[t] <- exp(log_c)
  }

  keep <- if (n_adapt < n_iter) (n_adapt + 1):n_iter else seq_len(n_iter)
  colnames(draws) <- if (d == 1) "theta" else paste0("theta_", seq_len(d))
  list(
    draws = as_tibble(draws) |> mutate(iteration = seq_len(n_iter), .before = 1),
    accept_rate = mean(accepted[keep]),
    step_sizes = tibble(iteration = seq_len(n_iter), step_size = step_sizes)
  )
}

# --- Chapter 7: Metropolis-Hastings with a user-supplied proposal --------------
#   propose(current) returns a candidate; log_q(to, from) returns log q(to | from).
metropolis_hastings <- function(log_target, init, n_iter, propose, log_q, ...) {
  d <- length(init)
  draws <- matrix(NA_real_, nrow = n_iter, ncol = d)
  current <- init
  current_lp <- log_target(current, ...)
  n_accept <- 0

  for (t in seq_len(n_iter)) {
    proposal <- propose(current)                             # 1. propose
    proposal_lp <- log_target(proposal, ...)
    log_r <- (proposal_lp - current_lp) +                    # 2. compare ...
      (log_q(current, proposal) - log_q(proposal, current))  # ... with the Hastings correction
    if (log(runif(1)) < log_r) {                             # 3. accept ...
      current <- proposal
      current_lp <- proposal_lp
      n_accept <- n_accept + 1
    }
    draws[t, ] <- current                                    # ... or stay and record
  }

  colnames(draws) <- if (d == 1) "theta" else paste0("theta_", seq_len(d))
  list(
    draws = as_tibble(draws) |> mutate(iteration = seq_len(n_iter), .before = 1),
    accept_rate = n_accept / n_iter
  )
}

# --- Chapter 8: Metropolis-within-Gibbs with per-coordinate adaptive steps -------
mwg <- function(log_target, init, n_iter, step_size = 1, n_adapt = n_iter %/% 2,
                gibbs_step = NULL, metropolis_index = seq_along(init), ...) {
  d <- length(init)
  m <- length(metropolis_index)
  draws <- matrix(NA_real_, nrow = n_iter, ncol = d)
  current <- init
  current_lp <- log_target(current, ...)
  log_step <- rep(log(step_size), length.out = m)
  n_accept <- numeric(m)

  for (t in seq_len(n_iter)) {
    if (!is.null(gibbs_step)) {                              # Gibbs steps
      current <- gibbs_step(current, ...)
      current_lp <- log_target(current, ...)
    }
    for (k in seq_len(m)) {                                  # one Metropolis step per coordinate
      j <- metropolis_index[k]
      proposal <- current
      proposal[j] <- rnorm(1, mean = current[j], sd = exp(log_step[k]))
      proposal_lp <- log_target(proposal, ...)
      alpha <- min(1, exp(proposal_lp - current_lp))
      if (runif(1) < alpha) {
        current <- proposal
        current_lp <- proposal_lp
        n_accept[k] <- n_accept[k] + 1
      }
      if (t <= n_adapt) log_step[k] <- log_step[k] + t^(-0.6) * (alpha - 0.44)
    }
    draws[t, ] <- current
  }

  colnames(draws) <- if (!is.null(names(init))) names(init) else paste0("theta_", seq_len(d))
  list(
    draws = as_tibble(draws) |> mutate(iteration = seq_len(n_iter), .before = 1),
    accept_rate = n_accept / n_iter,
    step_size = exp(log_step)
  )
}

# --- Chapter 11: Hamiltonian Monte Carlo with the leapfrog integrator -----------
hmc <- function(log_target, grad_log_target, init, n_iter, step_size, n_leapfrog, ...) {
  d <- length(init)
  draws <- matrix(NA_real_, nrow = n_iter, ncol = d)
  energy <- energy_error <- numeric(n_iter)
  current <- init
  current_lp <- log_target(current, ...)
  n_accept <- 0

  for (t in seq_len(n_iter)) {
    p <- rnorm(d)                                            # 1. refresh the momentum
    H_current <- -current_lp + sum(p^2) / 2
    theta <- current
    grad <- grad_log_target(theta, ...)
    p <- p + step_size / 2 * grad                            # 2. leapfrog: opening half step
    for (l in seq_len(n_leapfrog)) {
      theta <- theta + step_size * p                         #    full step for the position
      grad <- grad_log_target(theta, ...)
      if (l < n_leapfrog) p <- p + step_size * grad          #    merged half steps for the momentum
    }
    p <- p + step_size / 2 * grad                            #    closing half step
    proposal_lp <- log_target(theta, ...)
    H_proposal <- -proposal_lp + sum(p^2) / 2
    delta_H <- H_proposal - H_current
    if (is.finite(delta_H) && log(runif(1)) < -delta_H) {    # 3. accept ...
      current <- theta
      current_lp <- proposal_lp
      n_accept <- n_accept + 1
    }
    draws[t, ] <- current                                    # ... or stay and record
    energy[t] <- H_current
    energy_error[t] <- delta_H
  }

  colnames(draws) <- if (d == 1) "theta" else paste0("theta_", seq_len(d))
  list(
    draws = as_tibble(draws) |> mutate(iteration = seq_len(n_iter), .before = 1),
    accept_rate = n_accept / n_iter,
    diagnostics = tibble(iteration = seq_len(n_iter), energy = energy, energy_error = energy_error)
  )
}
