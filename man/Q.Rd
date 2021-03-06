% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/RcppExports.R
\name{Q}
\alias{Q}
\title{The loglikelihood function of lambda}
\usage{
Q(lambda, tauinv2, p)
}
\arguments{
\item{lambda}{a double value}

\item{tauinv2}{the vector}

\item{p}{the length of tauinv2}
}
\value{
a double value
}
\description{
The loglikelihood function of lambda
}
\examples{
\dontrun{
lambda<-1;tauinv2<-c(1,2,3);p<-length(tauinv2)
Q(lambda,tauinv2,p)
}
}
