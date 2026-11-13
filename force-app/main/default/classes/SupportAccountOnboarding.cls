public with sharing class SupportAccountOnboarding {
    private static final String SUPPORT_PERMISSION_SET_NAME = 'Support_Account_Triage_Access';

    /**
     * Creates a customer account and grants the selected support user onboarding access.
     *
     * @param accountName Name for the customer account.
     * @param supportUserId Internal support user receiving the access permission set.
     * @return ID of the created customer account.
     */
    public static Id createCustomerAccount(String accountName, Id supportUserId) {
        Account customerAccount = new Account(Name = accountName);
        insert customerAccount;

        PermissionSet supportAccess = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = :SUPPORT_PERMISSION_SET_NAME
            LIMIT 1
        ];
        PermissionSetAssignment assignment = new PermissionSetAssignment(
            AssigneeId = supportUserId,
            PermissionSetId = supportAccess.Id
        );
        insert assignment;

        return customerAccount.Id;
    }
}
