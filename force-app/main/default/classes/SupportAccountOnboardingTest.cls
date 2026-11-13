@IsTest
private with sharing class SupportAccountOnboardingTest {
    @TestSetup
    static void createSupportUser() {
        insert TestDataFactory.createSupportUser();
    }

    @IsTest
    static void createsAccountAndAssignsSupportAccess() {
        User supportUser = [
            SELECT Id
            FROM User
            WHERE LastName = 'Workshop Support Agent'
            LIMIT 1
        ];

        Test.startTest();
        Id accountId = SupportAccountOnboarding.createCustomerAccount(
            'Mixed DML Workshop Customer',
            supportUser.Id
        );
        Test.stopTest();

        Account createdAccount = [
            SELECT Id, Name
            FROM Account
            WHERE Id = :accountId
        ];
        List<PermissionSetAssignment> assignments = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :supportUser.Id
                AND PermissionSet.Name = 'Support_Account_Triage_Access'
        ];

        Assert.areEqual('Mixed DML Workshop Customer', createdAccount.Name);
        Assert.areEqual(1, assignments.size());
    }
}
