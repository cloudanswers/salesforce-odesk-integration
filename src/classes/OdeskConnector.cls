public with sharing class OdeskConnector {
   
    public String message{get;set;}
    private static FINAL String SERVICENAME = 'Odesk';


    public  void retrieveUserDetail(){
        String serviceEndpoint = 'https://www.odesk.com/api/hr/v2/users/me.json';
        sendRequest(serviceEndpoint,'GET');

    }

    public void retrieveJobs(){
        String serviceEndpoint = 'https://www.odesk.com/api/hr/v2/jobs.json?buyer_team__reference=3976918';
        sendRequest(serviceEndpoint,'GET');
    }

    public void retrieveEngagements(){
        String serviceEndpoint = 'https://www.odesk.com/api/hr/v2/engagements.json';
        sendRequest(serviceEndpoint,'GET');
    }

    /*Sends requests to endpoint after signing and adding in auth token for the service*/
    private  String sendRequest(String url,String method){        
        Http h = new Http();
        String body;        
        HttpRequest req = new HttpRequest();
        req.setMethod(method);
        req.setEndpoint(url);
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

     /*
    private final sObject mysObject;

    // The extension constructor initializes the private member
    // variable mysObject by using the getRecord method from the standard
    // controller.
    public OdeskConnector(ApexPages.StandardController stdController) {
        this.mysObject = (sObject)stdController.getRecord();
    }

    public String getRecordName() {
        return 'Hello ' + (String)mysObject.get('name') + ' (' + (Id)mysObject.get('Id') + ')';
    }
    */
}