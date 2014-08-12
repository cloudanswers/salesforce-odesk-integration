public class OdeskAPITest_Con {
    public String url{get;set;}
    public String response{get;set;}
    public String request{get;set;}
    public String method{get;set;}
    public String body{get;set;}
    public String param{get;set;}
    
    public void sendRequest(){
        
        String tUrl = url;
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setMethod(method);
        if(String.isNotBlank(param)){
            tUrl = url + '?' + EncodingUtil.urlencode(param,'UTF-8');
        }
        
        req.setEndpoint(url);
        if(String.isNotBlank(body)){
            req.setBody(body);
        }
        
        
        //sign request
        OAuth o = new Oauth();
        o.setService(UserInfo.getUserId(),'Odesk');
        o.sign(req);
        request = req.toString();
        HttpResponse res = h.send(req);
        response = res.getBody();
    }
}