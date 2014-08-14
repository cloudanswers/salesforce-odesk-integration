public with sharing class OdeskConnector {
   
    public String message{get;set;}
    private static FINAL String SERVICENAME = 'Odesk';


    public  void getUserDetail(){
        String serviceEndpoint = 'https://www.odesk.com/api/hr/v2/users/me.json';
        sendRequest(serviceEndpoint,'GET');

    }

    public void getJobs(String btr){
        String serviceEndpoint = 'https://www.odesk.com/api/hr/v2/jobs.json?buyer_team__reference='+btr;
        sendRequest(serviceEndpoint,'GET');
    }

    public void getEngagements(){
        String serviceEndpoint = 'https://www.odesk.com/api/hr/v2/engagements.json';
        sendRequest(serviceEndpoint,'GET');
    }

    public void getTeams(){
        sendRequest('https://www.odesk.com/api/hr/v2/teams.json','GET');
    }

    public void getTimeReports(String cid,String qry){
        sendRequest('https://www.odesk.com/gds/timereports/v1/companies/'+cid+'?tq='+qry,'GET');
    }

    /*Sends requests to endpoint after signing and adding in auth token for the service*/
    private  String sendRequest(String url,String method){        
        Http h = new Http();
        String body;        
        HttpRequest req = new HttpRequest();
        req.setMethod(method);
        req.setEndpoint(encodeURLParams(url));
        /*init OAuth class for signing the request*/
        OAuth oa = new OAuth();    
        if(!oa.setService(SERVICENAME)&&(!Test.isRunningTest())) {
            System.debug(oa.message);
            message=oa.message;
            return null;
        }
        /*Sign the request*/
        oa.sign(req);        
        System.debug(req.getHeader('Authorization'));
        HttpResponse res = h.send(req);
        body = res.getBody();
        System.debug('Received response ('+res.getStatusCode()+' '+res.getStatus()+')');
        System.debug('Received body -- '+body);
        
        return body;     
    }

    public static String encodeURLParams(String url){
        String encodedURL = '';
        if(String.isNotBlank(url)){
            for(String splt : url.split('&')){
                List<String> kv = splt.split('=');
                if(kv.size() > 1){
                    encodedURL = encodedURL+'&'+kv[0]+'='+urlEncode(kv[1]);
                }
                else{
                    encodedURL = String.isBlank(encodedURL) ? splt : (encodedURL+'&'+splt);
                }
            }
        }
        else{
            encodedURL = url;
        }

        return encodedURL;
    }

    private static String urlEncode(String url){
        if(String.isNotBlank(url)){
            url = EncodingUtil.urlEncode(url, 'UTF-8').replace('+','%20');
        }

        return url;
    }

}