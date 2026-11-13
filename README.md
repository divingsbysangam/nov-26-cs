# Nov 26 CS: ClaudeForce Workshop

A hands-on workshop about building with Salesforce skills and coding agents. The central idea: developers remain the daily drivers; agents become more useful when grounded in the project's code, business rules, and tests.

## Workshop Flow

The planned live sequence is:

1. **Debug a seeded Mixed DML failure.** Ask Claude Code to inspect the Apex service and failing test, diagnose the transaction problem, and fix it with regression coverage.
2. **Build automatic Jev Case triage.** Plan a Case triage workflow where Jev supplies bounded decisions and Salesforce automation owns all record updates and routing.

The exercises are independent. The Mixed DML sample is runnable starter code. The Jev Case triage work is currently a design brief, not an implemented integration.

## Repository Contents

- [`CASE_TRIAGE_SPEC.md`](CASE_TRIAGE_SPEC.md): Jev Case triage design, decision/action boundary, safety requirements, and evaluation scenarios.
- [`SupportAccountOnboarding.cls`](force-app/main/default/classes/SupportAccountOnboarding.cls): deliberately defective implementation for the Mixed DML exercise.
- [`SupportAccountOnboardingTest.cls`](force-app/main/default/classes/SupportAccountOnboardingTest.cls): test that exercises the failing onboarding path.
- [`TestDataFactory.cls`](force-app/main/default/classes/TestDataFactory.cls): isolated test-user factory.
- [`Support_Account_Triage_Access.permissionset-meta.xml`](force-app/main/default/permissionsets/Support_Account_Triage_Access.permissionset-meta.xml): permission set used by the sample service.

## Exercise 1: Mixed DML Debugging

The sample onboarding service creates a customer `Account`, then inserts a `PermissionSetAssignment` for an internal support user in the same transaction. `Account` is a business object; `PermissionSetAssignment` is a setup object. Salesforce rejects this combination with `MIXED_DML_OPERATION`.

The failure is intentional. The challenge is to reproduce it, explain the root cause, choose a Salesforce-supported transaction boundary, and make the Account creation and access assignment both succeed. Keep the error visible in the baseline; do not hide it with `try/catch` or use `System.runAs` around the failing invocation in the regression test.

### Run the Baseline Test

Use a dedicated scratch org or isolated training sandbox. **Do not deploy or run the intentionally failing sample in a production or shared demo org.** After deploying the starter to the isolated org, run:

```bash
sf apex run test --tests SupportAccountOnboardingTest --target-org <training-org> --result-format human --synchronous
```

The baseline is expected to fail with a Mixed DML error. After implementing a fix, rerun the same test and confirm that both the Account and permission assignment exist. Salesforce documents that test context can mask Mixed DML when setup DML is wrapped in `System.runAs`, so keep the failing call outside that wrapper.

### Claude Code Challenge Prompt

```text
Inspect the Mixed DML onboarding failure in this repository. Run the focused regression test in the configured isolated training org, explain the root cause from the DML sequence, and propose a Salesforce-supported fix before editing. Then implement the fix and tests so customer Account creation and support permission assignment both complete, with errors observable if the assignment cannot be completed. Do not use System.runAs to hide the failure, swallow the exception, or deploy this intentionally broken baseline to a shared or production org.
```

## Exercise 2: Automatic Jev Case Triage

The target workflow automatically starts after an eligible Case is created. A post-commit asynchronous process sends only the required Case context to TypeSafe Jev. Salesforce validates Jev's structured category/impact decisions and applies the configured threshold and routing rules. Uncertain, unsupported, security-sensitive, or failed decisions go to human review.

Jev decides; Salesforce acts. Jev must not update records, choose Salesforce IDs, or generate free-form summaries. The full design and test scenarios are in [`CASE_TRIAGE_SPEC.md`](CASE_TRIAGE_SPEC.md). Implementation is planned for a separate implementation org/repository, then packaged for the workshop demo org.

## Safety Notes

- Use synthetic Case and Account data for the workshop.
- Store any TypeSafe API key in Salesforce Named Credential/External Credential configuration. Never commit secrets, paste them into prompts, or include them in logs or tests.
- Do not use the broken Mixed DML starter against a production or shared demo org.
- Do not assume typed model output is correct; evaluate thresholds against labeled examples and route uncertain outcomes for review.

## References

- [Salesforce Skills and Plugins Library](https://github.com/forcedotcom/sf-skills)
- [TypeSafe: Introducing System One Models and Jev](https://typesafe.ai/blog/introducing-system-one-models-and-jev)
- [Salesforce: Mixed DML operations](https://developer.salesforce.com/docs/platform/apex-dev/references/apex-dev/apex-dml-non-mix-sobjects.html)
- [Salesforce: Named Credentials](https://developer.salesforce.com/docs/platform/named-credentials/guide/get-started)