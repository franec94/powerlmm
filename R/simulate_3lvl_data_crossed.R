simulate_3lvl_data_crossed <- function(paras) {
    do.call(.simulate_3lvl_data_crossed, paras)
}



create_cluster_index_crossed <- function(n2) {
    n3 <- length(n2)
    if(length(n2) == 1) {
        cluster <- rep(1:n3, each = n2)
    } else {
        # if(is.null(n2_func)) {
        cluster <- lapply(seq_along(n2), function(i) rep((1:n3)[i], each = n2[i]))
        cluster <- unlist(cluster) # index clusters
        #} else if(n2_func == "runif") {
        #     n2 <- floor(runif(n3, n2[1], n2[2]))
        #}

    }
    cluster

}
.simulate_3lvl_data_crossed <- function(n1,
                                 n2,
                                 n3,
                                 T_end,
                                 fixed_intercept,
                                 fixed_tx,
                                 fixed_slope,
                                 fixed_slope_time_tx,
                                 sigma_subject_intercept,
                                 sigma_subject_slope,
                                 sigma_cluster_intercept,
                                 sigma_cluster_slope,
                                 sigma_cluster_intercept_crossed,
                                 sigma_cluster_slope_crossed,
                                 sigma_error,
                                 cor_subject = 0,
                                 cor_cluster_intercept_slope = 0,
                                 cor_cluster_intercept_intercept_tx = 0,
                                 cor_cluster_intercept_slope_tx = 0,
                                 cor_cluster_slope_intercept_tx = 0,
                                 cor_cluster_slope_slope_tx = 0,
                                 cor_cluster_intercept_tx_slope_tx = 0,
                                 cor_within = 0,
                                 dropout = NULL,
                                 deterministic_dropout = NULL, ...) {

    # errors
    #if(!"MASS" %in% installed.packages()) stop("Package 'MASS' is not installed")

    # unbalanced n2
    #n2 <- unlist(n2)
    #  if(length(n2) != n3) stop("n2 and n3 do not mach")
    time <- seq(0, T_end, length.out = n1) # n1 measurements during the year

    n2_func <- names(n2)
    cluster <- lapply(n2, create_cluster_index_crossed)
    tot_n2 <- length(unlist(cluster))
    subject <- rep(1:tot_n2, each = n1) # subject IDs
    TX <- rep(0, length(cluster$treatment), each = n1)
    CC <- rep(1, length(cluster$control), each = n1)
    TX <- c(CC, TX)
    # level-2 variance matrix
    Sigma_subject = c(
        sigma_subject_intercept^2 ,
        sigma_subject_intercept * sigma_subject_slope * cor_subject,
        sigma_subject_intercept * sigma_subject_slope * cor_subject,
        sigma_subject_slope^2
    )
    Sigma_subject <- matrix(Sigma_subject, 2, 2) # variances
    # level-3 variance matrix
    cV0V1 <- sigma_cluster_intercept * sigma_cluster_slope * cor_cluster_intercept_slope
    cV0V2 <- sigma_cluster_intercept * sigma_cluster_intercept_crossed * cor_cluster_intercept_intercept_tx
    cV0V3 <- sigma_cluster_intercept * sigma_cluster_slope_crossed * cor_cluster_intercept_slope_tx
    cV1V2 <- sigma_cluster_slope * sigma_cluster_intercept_crossed * cor_cluster_slope_intercept_tx
    cV1V3 <- sigma_cluster_slope * sigma_cluster_slope_crossed * cor_cluster_slope_slope_tx
    cV2V3 <- sigma_cluster_intercept_crossed * sigma_cluster_slope_crossed * cor_cluster_intercept_tx_slope_tx
    Sigma_cluster <- c(sigma_cluster_intercept^2, cV0V1, cV0V2,    cV0V3,
                       cV0V1, sigma_cluster_slope^2,     cV1V2,    cV1V3,
                       cV0V2, cV1V2, sigma_cluster_intercept_crossed^2, cV2V3,
                       cV0V3, cV1V3, cV2V3,     sigma_cluster_slope_crossed^2)
    Sigma_cluster <-  matrix(Sigma_cluster, 4, 4)
    # level 3-model
    cluster_lvl <-
        MASS::mvrnorm(length(unique(cluster$treatment)),
                      mu = c(0, 0, 0, 0),
                      Sigma = Sigma_cluster, 
                      empirical = FALSE)

    if (is.null(dim(cluster_lvl))) {
        # if theres only one therapist
        cluster_b0 <- cluster_lvl[1]
        cluster_b1 <- cluster_lvl[2]
        cluster_b2 <- cluster_lvl[3]
        cluster_b3 <- cluster_lvl[4]
    } else {
        cluster_b0 <- cluster_lvl[, 1] # intercept c
        cluster_b1 <- cluster_lvl[, 2] # slope c
        cluster_b2 <- cluster_lvl[, 3] # intercept tx
        cluster_b3 <- cluster_lvl[, 4] # slope time:tx
    }
    cluster <- unlist(cluster)
    v0 <- cluster_b0[cluster][subject]
    v1 <- cluster_b1[cluster][subject]
    v2 <- cluster_b2[cluster][subject]
    v3 <- cluster_b3[cluster][subject]

    # level 2- model
    subject_lvl <- MASS::mvrnorm(tot_n2, c(0, 0), Sigma_subject)
    u0 <- subject_lvl[, 1][subject]
    u1 <- subject_lvl[, 2][subject]

    # Combine
    b0 <- fixed_intercept + fixed_tx * TX + u0 + v0 + v2 * TX
    b1 <- fixed_slope + fixed_slope_time_tx * TX + u1 + v1 + v3 * TX

    # level-1 residuals
    sigma.y <- diag(n1)
    sigma.y <-
        sigma_error ^ 2 * cor_within^abs(row(sigma.y) - col(sigma.y)) # AR(1)

    # gen level-1 error
    error_sigma.y <- MASS::mvrnorm(tot_n2, rep(0, n1), sigma.y)

    # combine parameters
    y <- b0 + b1 * time + c(t(error_sigma.y))
    df <-
        data.frame (y,
                    y_c = y,
                    time,
                    treatment = TX,
                    subject,
                    cluster = rep(cluster, each = n1),
                    intercept_subject = u0,
                    slope_subject = u1,
                    intercept_cluster = v0,
                    intercept_cluster_tx = v2,
                    slope_cluster = v1,
                    slope_cluster_time_tx = v3,
                    miss = 0)

    df
}



