#' @title Dataset
#' @name Data
#' @description Dataset
#' @examples 
#' \dontrun{
#' data(Data)
#' attach(Data)
#' }
NULL

#' @title A Bayesian Lasso Regression function with gibbs sampling
#' @name BayesianLasso
#' @description A function that can complete the Bayesian Lasso Regression and  can use empirical bayes and hyperpriors method.
#' @references Park, Trevor, and George Casella. "The bayesian lasso." Journal of the American Statistical Association 103.482 (2008): 681-686.
#' @param x predictor variables 
#' @param y response variable
#' @param center TRUE/FALSE (default: TRUE, if the design matrix x has been centered) 
#' @param scale TRUE/FALSE (default: TRUE, if the design matrix x has been scaled)
#' @param n.max n of interations (default: 10000)
#' @param E TRUE/FALSE (default: TRUE, estimating lambda by empircal bayes; FALSE, estimating lambda by Hyperprior method.)
#' @param r,d hyper-Gamma prior for lambda^2 if E = FALSE
#' @return beta: the median of matrix Beta.
#' @return tau2: the median of matrix Tau2
#' @return sigma2: the median of vector Sigma2
#' @return lambda: the median of vector Lambda
#' @examples 
#' \dontrun{
#' data(Data)
#' attach(Data)
#' x<-Data$diabetes.x
#' y<-Data$diabetes.y
#' BayesianLasso(x,y)
#' }
#' @import Rcpp
#' @import graphics
#' @import rmarkdown
#' @import boot
#' @import bootstrap
#' @import knitr
#' @import RANN
#' @import energy
#' @import Ball
#' @import datasets
#' @import parallel
#' @import microbenchmark
#' @importFrom MASS ginv
#' @importFrom mvtnorm rmvnorm
#' @importFrom pscl rigamma
#' @importFrom statmod rinvgauss
#' @importFrom stats median
#' @importFrom knitr kable
#' @useDynLib StatComp21038 
#' @export 
BayesianLasso<-function(x,y,center = T, scale = T,n.max=10000,E=TRUE,r=1,d=1){
  #beginning
  #require("MASS")    # for the inverse of matrix
  #require("mvtnorm") #multivarate normal
  #require("pscl")    #inverse gamma
  #require("statmod") #inverse gaussian 
  #require("Rcpp")    #for we can use cpp function in the function
  #sourceCpp(paste0("//Users/apple/Desktop/StatComp/src/","StatComp.cpp"))
  x <- as.matrix(x)
  n <- nrow(x)
  p <- ncol(x)
  #centring and scaling
  ybar<-mean(y)
  yc<-y-ybar
  if(center==T){
    if(scale==T){
      xc<-x
    }
    else{
      xc<-scale(x,scale=T)
    }
  }
  else{
    if(scale==T){
      xc<-scale(x,center = T,scale = F)
    }
    else{
      xc<-scale(x,center = T,scale = F) 
    }
  }
  xbar<-apply(x,2,mean)
  xtx<-t(xc)%*%xc
  xty<-t(xc)%*%yc
  # initial
  beta <- drop(ginv(xtx)%*%xty)
  resid <- yc - xc %*% beta
  sigma2 <- (t(resid) %*% resid)/(n-p)
  tauinv2 <- 1 / (beta * beta)
  lambda <- p * sqrt(sigma2) / sum(abs(beta))
  #the loglike function prepare for the mento carlo EM
  L0 <- p*log(lambda^2)-lambda^2/2*sum(1/tauinv2) 
  Beta <- matrix(0, n.max, p)
  Sigma2 <- numeric(n.max)
  Tau2 <- matrix(0, n.max, p)
  Lambda <- numeric(n.max)
  # gibbs sampling
  for(i in 1:n.max){
    Dinv <- diag(tauinv2)
    Ainv <- ginv(xtx + Dinv)
    beta.m <- Ainv %*% xty
    Sigma <- as.numeric(sigma2) * Ainv
    # update beta
    if(det(Sigma)<0.001){
      beta <- rmvnorm(1, beta.m, Sigma, "svd") # for we can consider the matrix is singular
    } else{
      beta <- rmvnorm(1, beta.m, Sigma, "chol")
    }
    Beta[i,]<-beta
    # update sigma2
    sig.a <- (n-1)/2+p/2
    resid <- yc - xc %*% t(beta)
    sig.b <- t(resid) %*% resid/2 + beta%*% Dinv%*% t(beta)/2
    sigma2 <- rigamma(1, alpha=sig.a, beta=sig.b) #change inv-gamma function#
    Sigma2[i] <- sigma2
    # update tau2
    beta<-as.vector(beta)
    mu.t<-numeric(p)
    for(k in 1:p){
      mu.t[k]<-sqrt(lambda^2 * sigma2 / beta[k]^2)
    }
    lambda.t <- lambda^2
    tauinv2 <- rinvgauss(p, mean=mu.t, shape=lambda.t)
    Tau2[i, ] <- 1/tauinv2
    if(E==T){
      tol<-10^(-3)
      lambda<-EB(L0,tol,tauinv2,p,lambda)[1]
      L0<-EB(L0,tol,tauinv2,p,lambda)[2]
    }
    else{
      lambda<-HP(tauinv2,r,d,p)
    }
    Lambda[i]<-lambda
  }
  
  
  list(beta=round(apply(Beta[seq(round(n.max/2), n.max),],2, median),3),
       tau2=round(apply(Tau2[seq(round(n.max/2), n.max),],2,  median),3),
       sigma2=round(median(Sigma2[seq(round(n.max/2), n.max)]),3),
       lambda=round(median(Lambda[seq(round(n.max/2), n.max)]),3))
}

#' @title Compare with the existing function blasso in R package \code{monomvn}
#' @name Compare
#' @description We compare the MSE which generates from the function we write with the function \code{blasso} in \code{monomvn}
#' @examples 
#' \dontrun{
#' library(monomvn)
#' data(Data)
#' attach(Data)
#' x<-Data$diabetes.x
#' y<-Data$diabetes.y
#' n<-nrow(Data$diabetes.x)
#' yc<-y-mean(y)
#' result<-BayesianLasso(x,y)
#' proc.time()
#' resid<-yc-x%*%result$beta
#' mse1<-t(resid)%*%resid/n
#' n.max=1e4
#' result1<-blasso(x,y,T=n.max)
#' proc.time()
#' result2<-round(apply(result1$beta[seq(round(n.max/2),n.max),],2, median),3)
#' resid<-yc-x%*%result2
#' mse2<-t(resid)%*%resid/n
#' mse1;mse2
#' }
#' @import monomvn
#' @import Rcpp 
#' @importFrom MASS ginv
#' @importFrom mvtnorm rmvnorm
#' @importFrom pscl rigamma
#' @importFrom statmod rinvgauss
#' @importFrom stats median
#' @importFrom monomvn blasso
#' @useDynLib StatComp21038 
NULL






