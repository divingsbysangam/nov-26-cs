# Nov 26 CS: Claudeforce Workshop

A hands-on workshop about building with Claude and Salesforce. The central idea: developers remain the daily drivers, and agents become more useful when they are grounded in the project, the org and the business rules.

This repository holds the written guides for the two use cases. It contains no Salesforce project code. You generate the React app yourself in the second use case.

## Use cases

1. **[Use Case 1: Connect Claude to Salesforce with Headless 360](HEADLESS_360_MCP_CLAUDE_SETUP.md).** Activate the Headless 360 MCP server in a Developer Edition org, create an External Client App, add a custom connector in Claude, and test it against Cases.
2. **[Use Case 2: React Case Pipeline Board](CASE_PIPELINE_REACT_APP.md).** Use Claude Code with the Salesforce Development plugin to build a React Case pipeline app (Salesforce Multi-Framework) that reads and updates Cases with the Salesforce Data SDK and GraphQL, then deploy it to the org.

Use case 2 builds on use case 1: the connection from use case 1 lets Claude inspect the org and help load synthetic data.

## Before you start

- A Salesforce Developer Edition org on Hyperforce, with Salesforce Multi-Framework enabled and the Salesforce App Domain active.
- Salesforce CLI and Node.js 18 or later.
- Claude Code, and the Salesforce Development plugin for Claude Code.
- A Claude account that can add custom connectors.
- Synthetic Cases in the org. The guides describe how to load them.

## Safety notes

- Use synthetic data only.
- Never commit a Consumer Key, Consumer Secret, token or any other secret to this repository.
- Test in a Developer Edition org, scratch org or sandbox before using any shared org.
- The Headless 360 MCP server is a beta service, so settings and screens can change.

## References

- [Salesforce Multi-Framework documentation](https://developer.salesforce.com/docs/platform/multiframework/guide)
- [Salesforce hosted MCP servers: create an External Client App](https://developer.salesforce.com/docs/platform/hosted-mcp-servers/guide/create-external-client-app.html)
- [Salesforce Skills and Plugins Library](https://github.com/forcedotcom/sf-skills)
