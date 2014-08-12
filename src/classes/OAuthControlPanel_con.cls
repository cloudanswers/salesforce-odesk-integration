/*
*   DESCRIPTION:Controller class that handles the authorization
**/
public with sharing class OAuthControlPanel_con {

    public String authUrl { get; set; }
    public boolean authSuccess { get; set; }
    public String message { get; set; }
    public Boolean authState {get; set;}

    private static FINAL String SERVICENAME = 'Odesk';
    private Oauth_token__c token = new Oauth_token__c ();

    public OAuthControlPanel_con() {
        try {
            token = getSetting();
            authState = true;
        } catch (System.QueryException e) {
            authState = false;
        }
    }


    public PageReference authorize() {
        OAuth oa = new OAuth();
        authUrl = oa.newAuthorization(SERVICENAME);
        System.debug(authUrl);
        if (authUrl == null) {
            this.message = oa.message;
            return null;
        } else {
            return new PageReference(authUrl);
        }
    }

    public PageReference completeAuthorization() {
        String token = ApexPages.currentPage().getParameters().get('oauth_token');
        if (token != null) {
            String verifier = ApexPages.currentPage().getParameters().get('oauth_verifier');
            OAuth oa = new OAuth();
            authSuccess = oa.completeAuthorization(token, verifier);
            this.message = oa.message;
        } else {
            message = 'Invalid request. Missing parameter oauth_token';
        }
        return null;
    }


    public void revokeAccess() {
        delete getSetting();
        authState = false;
    }

    private OAuth_Token__c getSetting() {
        return [
                   SELECT
                   token__c,
                   secret__c,
                   isAccess__c
                   FROM
                   OAuth_Token__c
                   WHERE
                   owner__c = : UserInfo.getUserId()
                      AND
                      Name = : SERVICENAME
                      LIMIT 1
               ];
    }
}