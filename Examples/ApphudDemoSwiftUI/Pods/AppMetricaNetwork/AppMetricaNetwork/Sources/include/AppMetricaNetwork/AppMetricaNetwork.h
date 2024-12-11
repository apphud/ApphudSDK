
#if __has_include("AppMetricaNetwork.h")
    #import "AMAGenericRequest.h"
    #import "AMAHTTPRequestor.h"
    #import "AMAHTTPRequestsFactory.h"
    #import "AMAHTTPSessionProvider.h"
    #import "AMAHostExchangeRequestProcessor.h"
    #import "AMAHostExchangeResponseValidating.h"
    #import "AMANetworkSessionProviding.h"
    #import "AMANetworkStrategyController.h"
    #import "AMANetworkingUtilities.h"
    #import "AMAReportResponse.h"
    #import "AMAReportResponseParser.h"
    #import "AMARequest.h"
    #import "AMARequestParameters.h"
#else
    #import <AppMetricaNetwork/AMAGenericRequest.h>
    #import <AppMetricaNetwork/AMAHTTPRequestor.h>
    #import <AppMetricaNetwork/AMAHTTPRequestsFactory.h>
    #import <AppMetricaNetwork/AMAHTTPSessionProvider.h>
    #import <AppMetricaNetwork/AMAHostExchangeRequestProcessor.h>
    #import <AppMetricaNetwork/AMAHostExchangeResponseValidating.h>
    #import <AppMetricaNetwork/AMANetworkSessionProviding.h>
    #import <AppMetricaNetwork/AMANetworkStrategyController.h>
    #import <AppMetricaNetwork/AMANetworkingUtilities.h>
    #import <AppMetricaNetwork/AMAReportResponse.h>
    #import <AppMetricaNetwork/AMAReportResponseParser.h>
    #import <AppMetricaNetwork/AMARequest.h>
    #import <AppMetricaNetwork/AMARequestParameters.h>
#endif
