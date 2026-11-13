@IsTest
public with sharing class TestDataFactory {
    /**
     * Creates an unsaved internal support user for isolated Apex tests.
     *
     * @return A uniquely named standard user.
     */
    public static User createSupportUser() {
        Profile standardProfile = [
            SELECT Id
            FROM Profile
            WHERE UserType = 'Standard'
            LIMIT 1
        ];
        String uniqueSuffix = String.valueOf(DateTime.now().getTime())
            + String.valueOf(Crypto.getRandomInteger());
        String username = 'support.triage.' + uniqueSuffix + '@example.test';

        return new User(
            Alias = 'support',
            Email = username,
            EmailEncodingKey = 'UTF-8',
            LastName = 'Workshop Support Agent',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = username
        );
    }
}
