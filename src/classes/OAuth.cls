/*
*    -------------------------------------------------------------------------------
*   DESCRIPTION: This class handles everything related to Oauth with Odesk
*   --------------------------------------------------------------------------------
**/
public class OAuth {
    private OAuth_Connection__c service;
    private String token;
    private String tokenSecret;
    private Boolean isAccess = false;
    private String verifier;

    private String nonce;
    private String timestamp;
    private String signature;
    private String consumerKey {get; set;}
    private String consumerSecret {get; set;}
    private String settingName;
    private Map<String, String> parameters = new Map<String, String>();
    private Boolean newAuthorizationFlag = true;
    public String message { get; set; }
    public String callbackUrl {get; set; }



    /**
     * Looks up service name and starts a new authorization process
     * returns the authorization URL that the user should be redirected to
     * If null is returned, the request failed. The message property will contain
     * the reason.
     */
    public String newAuthorization(String settingName) {
        this.settingName = settingName;
        newAuthorizationFlag = true;
        service = OAuth_Connection__c.getValues(settingName);

        if (service == null) {
            System.debug('Couldn\'t find Oauth Service ' + settingName);
            message = 'Service was not found in the local configuration';
            return null;
        }

        if (callbackUrl == null) {
            if (ApexPages.currentPage() == null || ApexPages.currentPage().getHeaders().get('Host') == null) {
                message = 'No callback page was set and it couldn\'t be generated from Apex context';
                System.debug(message);
                return null;
            }

            callbackUrl = EncodingUtil.urlEncode('https://' + ApexPages.currentPage().getHeaders().get('Host') +
                                                 Page.CompleteAuth.getUrl() + '?id=' + UserInfo.getUserId(), 'UTF-8');
        }

        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(service.request_token_url__c);
        System.debug('Request body set to: ' + req.getBody());
        consumerKey = service.consumer_key__c;
        consumerSecret = service.consumer_secret__c;
        sign(req);
        HttpResponse res = null;
        if (!Test.isRunningTest()) {
            res = h.send(req);

            System.debug('Response from request token request: (' + res.getStatusCode() + ')' + res.getBody());
            if (res.getStatusCode() > 299) {
                message = 'Failed getting a request token. HTTP Code = ' + res.getStatusCode() +
                          '. Message: ' + res.getStatus() + '. Response Body: ' + res.getBody();
                return null;
            }
        }
        //String resParams=res.getBody();
        String resParams = Test.isRunningTest() == true ?
                           'oauth_token=token&oauth_token_secret=token_secret' : res.getBody();
        Map<String, String> rp = getUrlParams(resParams);
        OAuth_Token__c t = new OAuth_Token__c();
        t.owner__c = UserInfo.getUserId();
        t.token__c = rp.get('oauth_token');
        t.secret__c = rp.get('oauth_token_secret');
        t.isAccess__c = false;
        t.Name = settingName;
        /*Delete any existing token for the same user for the same service*/
        delete [
            SELECT
            token__c,
            secret__c,
            isAccess__c
            FROM
            OAuth_Token__c
            WHERE
            owner__c = : UserInfo.getUserId()
            AND
            Name =:settingName
        ];

        insert t;

        System.debug('Got request token: ' + t.token__c + '(' + rp.get('oauth_token') + ')');

        if (service.authorization_url__c.contains('?')) {
            return service.authorization_url__c + '&oauth_token=' + EncodingUtil.urlDecode(t.token__c, 'UTF-8') + '&oauth_consumer_key=' + service.consumer_key__c;
        } else {
            return service.authorization_url__c + '?oauth_token=' + EncodingUtil.urlDecode(t.token__c, 'UTF-8') + '&oauth_consumer_key=' + service.consumer_key__c;
        }
    }

    public boolean completeAuthorization(String token, String verifier) {
        System.debug('Completing authorization for request token ' + token + ' with verifier ' + verifier);
        OAuth_Token__c t = null;
        try {
            t = [
                    SELECT
                    token__c,
                    secret__c,
                    isAccess__c,
                    Name
                    FROM
                    OAuth_Token__c
                    WHERE
                    owner__c = : UserInfo.getUserId()
                               AND
                               token__c = : EncodingUtil.urlEncode(token, 'UTF-8')
                               AND isAccess__c = false
                ];

        } catch (System.QueryException e) {
            message = 'Unknown request token: ' + token + '. Restart authorization process';
            System.debug(message);
            return false;

        }

        this.settingName = t.Name;
        service = OAuth_Connection__c.getValues(t.Name);
        consumerKey = service.Consumer_Key__c;
        consumerSecret = service.Consumer_Secret__c;
        this.token = t.token__c;
        tokenSecret = t.secret__c;
        if (verifier != null) {
            this.verifier = EncodingUtil.urlEncode(verifier, 'UTF-8');
        }

        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(service.access_token_url__c);
        req.setBody('');
        /*Sign the request*/
        sign(req);
        HttpResponse res = null;
        if (Test.isRunningTest()) {
            res = new HttpResponse();
        } else {
            res = h.send(req);
            System.debug('Response from request token request: (' + res.getStatusCode() + ')' + res.getBody());
        }
        if (res.getStatusCode() > 299) {
            message = 'Failed getting an access token. HTTP Code = ' + res.getStatusCode() + '. Message: ' + res.getStatus() + '. Response Body: ' + res.getBody();
            return false;
        }
        //String resParams=res.getBody();
        String resParams = Test.isRunningTest() == true ?
                           'oauth_token=token&oauth_token_secret=token_secret' : res.getBody();

        Map<String, String> rp = new Map<String, String>();
        for (String s : resParams.split('&')) {
            List<String> kv = s.split('=');
            rp.put(kv[0], kv[1]);
            System.debug('Access token response param: ' + kv[0] + '=' + kv[1]);
        }

        t.token__c = rp.get('oauth_token');
        t.secret__c = rp.get('oauth_token_secret');
        t.isAccess__c = true;

        update t;

        return true;
    }


    public boolean setService(String settingName) {
        return setService(UserInfo.getUserId(),settingName);
    }

    public boolean setService(ID userId, String settingName) {
        this.settingName = settingName;
        /*Flag to check whether is a new auth request or a request to a REST resource*/
        newAuthorizationFlag = false;
        OAuth_Token__c t = null;
        try {
            t = [
                    SELECT
                    token__c,
                    secret__c,
                    isAccess__c
                    FROM
                    OAuth_Token__c
                    WHERE
                    owner__c = : userId
                               AND
                               isAccess__c = true
                               AND Name=:settingName
                ];

        } catch (System.QueryException e) {
            message = 'User ' + UserInfo.getUserName() + ' did not authorize access to LinkedIn. Redirect user to authorization page. [' + e + ']';
            System.debug(message);
            return false;
        }
        service = OAuth_Connection__c.getValues(settingName);

        System.debug('Preparing OAuth request to service ' + service.name);

        consumerKey = service.Consumer_Key__c;
        consumerSecret = service.Consumer_Secret__c;
        this.token = t.token__c;
        tokenSecret = t.secret__c;
        return true;
    }

    /*Method to popuplate the oauth related parameters*/
    private void refreshParameters() {
        parameters.clear();
        parameters.put('oauth_consumer_key', consumerKey);
        if (token != null) {
            parameters.put('oauth_token', token);
        }
        if (verifier != null) {
            parameters.put('oauth_verifier', verifier);
        }
        parameters.put('oauth_signature_method', 'HMAC-SHA1');
        parameters.put('oauth_timestamp', timestamp);
        parameters.put('oauth_nonce', nonce);
        if (callbackUrl != null) {
            parameters.put('oauth_callback', callbackUrl);
        }
    }
    /*
    private Map<String, String> getUrlParams(String value) {
        Map<String, String> res = new Map<String, String>();
        if (value == null || value == '') {
            return res;
        }
        for (String s : value.split('&')) {
            List<String> kv = s.split('=');
            if (kv.size() > 1) {
                res.put(kv[0], kv[1]);
            }
        }
        return res;
    }
    */
    private Map<String,String> getUrlParams(String value) {
    Map<String,String> res = new Map<String,String>();
    if(value==null || value=='') {
        return res;
    }
    for(String s : value.split('&')) {
        System.debug('getUrlParams: '+s);
        List<String> kv = s.split('=');
        if(kv.size()>1) {
            // RFC 5849 section 3.4.1.3.1 and 3.4.1.3.2 specify that parameter names 
            // and values are decoded then encoded before being sorted and concatenated
            // Section 3.6 specifies that space must be encoded as %20 and not +
            String encName = EncodingUtil.urlEncode(EncodingUtil.urlDecode(kv[0], 'UTF-8'), 'UTF-8').replace('+','%20');
            String encValue = EncodingUtil.urlEncode(EncodingUtil.urlDecode(kv[1], 'UTF-8'), 'UTF-8').replace('+','%20');
            System.debug('getUrlParams:  -> '+encName+','+encValue);
            res.put(encName,encValue);
        }
    }
    return res;
}

    private String createBaseString(Map<String, String> oauthParams, HttpRequest req) {
        Map<String, String> p = oauthParams.clone();
        if (req.getMethod().equalsIgnoreCase('post') && req.getBody() != null &&
                req.getHeader('Content-Type') == 'application/x-www-form-urlencoded') {
            p.putAll(getUrlParams(req.getBody()));
        }
        String host = req.getEndpoint();
        Integer n = host.indexOf('?');
        if (n > -1) {
            p.putAll(getUrlParams(host.substring(n + 1)));
            host = host.substring(0, n);
        }
        List<String> keys = new List<String>();
        keys.addAll(p.keySet());
        keys.sort();
        String s = keys.get(0) + '=' + p.get(keys.get(0));
        for (Integer i = 1; i < keys.size(); i++) {
            s = s + '&' + keys.get(i) + '=' + p.get(keys.get(i));
        }
        /*27-SEP-2013 : THIS WAS THE BUG DUE TO WHICH AUTH WAS FAILING WITH ODESK, 
        ODESK doesn't need the base string in body for requests other than authorization
        */
        if(newAuthorizationFlag == true && settingName.equalsIgnoreCase('Odesk')){
            req.setBody(s);
        }
        
        //req.setBody(s);

        // According to OAuth spec, host string should be lowercased, but Google and LinkedIn
        // both expect that case is preserved.
        return req.getMethod().toUpperCase() + '&' +
               EncodingUtil.urlEncode(host, 'UTF-8') + '&' +
               EncodingUtil.urlEncode(s, 'UTF-8');
    }

    public void sign(HttpRequest req) {
        /*Generate oauth nonce*/
        nonce = String.valueOf(Crypto.getRandomLong());
        /*Timestamp for oauth*/
        timestamp = String.valueOf(DateTime.now().getTime() / 1000);
        refreshParameters();
        String s = createBaseString(parameters, req);
        System.debug('Signature base string: ' + s);
        /*Create the signature*/
        Blob sig = Crypto.generateMac('HmacSHA1', Blob.valueOf(s),Blob.valueOf(consumerSecret + '&' +(tokenSecret != null ? tokenSecret : '')));
        signature = EncodingUtil.urlEncode(EncodingUtil.base64encode(sig), 'UTF-8');
        System.debug('Signature: ' + signature);
        /*Generate Authorization header*/
        String header = 'OAuth ';       
        for (String key : parameters.keySet()) {
            header = header + key + '="' + parameters.get(key) + '", ';
            
        }
        header = header + 'oauth_signature="' + signature + '"';
        System.debug('Authorization: ' + header);
        req.setHeader('Authorization', header);
       
    }
}