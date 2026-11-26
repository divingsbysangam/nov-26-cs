# Use Case 2: React Case Pipeline Board

This use case builds on [Use Case 1: connect Claude to Salesforce with the Headless 360 MCP Server](HEADLESS_360_MCP_CLAUDE_SETUP.md). That connection is how Claude can inspect the org and help load synthetic Cases.

An internal Case management pipeline, built as a React app that runs inside Salesforce (Salesforce Multi-Framework, UI bundle) using Claude Code, the Salesforce Development plugin and the Salesforce Data SDK with GraphQL. This document records what we built in the first session, how to repeat it, and what is still open.

> Use synthetic data only. Build and test in a Developer Edition org, scratch org or sandbox.

## What it is

A board at the route `/cases` with one column per Case Status: **New, Working, Escalated, Closed**.

- Each card shows the Subject, a colour-coded Priority badge, the Origin with an icon, and the Case number.
- Dragging a card to another column updates the Case Status through a GraphQL mutation. The card moves immediately with a spinner and rolls back with an error message if Salesforce rejects the change.
- Clicking a card (or pressing Enter on it) opens a detail panel with Description, Priority, Origin and Created date. The panel includes a Status dropdown for touch and keyboard users, because browser drag-and-drop does not work on touch screens.
- Loading skeletons, an error banner and a Refresh button.
- The read query returns the 200 newest Cases and the page says so if there are more.

## Prerequisites

- A Developer Edition org on Hyperforce with Salesforce Multi-Framework enabled and the Salesforce App Domain active (see [HEADLESS_360_MCP_CLAUDE_SETUP.md](HEADLESS_360_MCP_CLAUDE_SETUP.md)).
- Salesforce CLI, Node.js 18 or later, Claude Code.
- The Salesforce Development plugin for Claude Code. In our session the plugin also recommended the React UI bundle plugin (`experience-react`), which we installed from `/plugin`.
- The org authorized in the CLI.
- Cases in the org. Our Developer Edition org started with none, so we loaded 30 synthetic Cases with Salesforce Inspector Reloaded (Status values New, Working, Escalated, Closed; Priority High, Medium, Low; Origin Phone, Email, Web).

## Steps

1. Generate the project in its own folder. This repository holds documentation only and has no Salesforce project.

   ```bash
   sf template generate project --name CasePipelineApp --template reactinternalapp
   cd CasePipelineApp
   ```

2. Open Claude Code in `CasePipelineApp`.

3. Optional: add the Salesforce skills library with `npx skills add forcedotcom/sf-skills`. In our session this installed every skill in the library (268) into the project. Many duplicate the skills that the plugins already provide, so install only the ones you need, or skip this step if the plugins are installed.

4. Give Claude Code this prompt:

   ```text
   Build an internal Case pipeline board in this React UI bundle. Show Cases in columns by Status (New, Working, Escalated, Closed). Each card shows Subject, a Priority badge, and Origin. Dragging a card to another column updates the Case Status. Clicking a card opens a detail panel with Description. Read and write Cases using the Salesforce Data SDK with GraphQL, not hardcoded data. Keep the UI clean and responsive. Run the build and fix any errors before finishing.
   ```

5. Run it locally from `force-app/main/default/uiBundles/CasePipelineApp` with `npm run dev`. The app served at `http://127.0.0.1:5173/cases` and the dev server forwarded GraphQL calls to the org using the CLI login. The board query returned our 30 Cases (10 New, 9 Working, 6 Escalated, 5 Closed).

6. Deploy with Claude Code (it loaded the UI bundle deploy skill) or with the CLI. The deploy included the `CasePipelineApp` Lightning app, the UI bundle and the `CasePipelineApp_Access` permission set, and assigned the permission set to the deploying user.

7. Open it from the App Launcher: CasePipelineApp, then Case Pipeline in the navigation.

## Where the code lives

```
force-app/main/default/uiBundles/CasePipelineApp/src/
  api/case/query/getCasePipeline.graphql        read query (200 newest Cases)
  api/case/mutation/updateCaseStatus.graphql    status update mutation
  features/case-pipeline/
    api/caseService.ts                          data layer (Data SDK GraphQL)
    hooks/useCasePipeline.ts                    query handle, refresh, pending moves
    components/                                 CaseCard, PipelineColumn, CaseDetailPanel, PriorityBadge
    constants.ts                                status and priority styles
    CasePipelinePage.tsx                        the board page
  routes.tsx                                    adds the /cases route and nav link
```

Pending moves are kept apart from server data and laid over each snapshot, so a refresh does not snap a card back.

## Problems we hit and how they were handled

| Problem | What was done |
| --- | --- |
| `npm install` crashed (a known npm 10 peer-dependency bug involving jsdom) | Installed with `--legacy-peer-deps`. Anyone installing later needs the same flag until npm fixes the bug. |
| The build then failed because old copies of two Salesforce SDK dependencies were left behind | Added `o11y@^268.2.0` and `o11y_schema@^268.165.0` to `package.json`, the versions the SDK requires. |
| A TypeScript error from the SDK's helper type for list results | Derived the Case node type directly from the generated query type. |

The build passes with 0 lint errors. The 11 lint warnings and Vite's "chunk larger than 500 kB" warning come from the template's existing code.

## What was and was not verified

Verified:
- `npm run build` passes.
- The read query runs against the org and returned 30 Cases through the dev server.
- The deploy succeeded and the permission set was assigned.

Not verified:
- The app was not opened in a browser, either locally or inside Lightning.
- Drag-to-update was not run against the org. Dragging changes real Case data.

## Access note

`CasePipelineApp_Access` as generated does not grant edit access to Case Status. Other users need read and edit access to Case and its fields, or drag-to-update will fail for them. A System Administrator already has this.

## Cleaning up the demo org

After the first run, the app, the permission set (after removing its assignment, since Salesforce will not delete an assigned permission set), and all 30 Cases were removed with a destructive deploy and a data delete. The Cases were backed up to a local CSV first and remain in the Recycle Bin for 15 days. The project source stays on disk, so the app can be redeployed.

## Next features

Tracked in Linear under the "React Case Pipeline Board" epic: verify the deployed app in Lightning, edit access for Case Status, filters and search, loading more than 200 Cases, creating a Case from the board, an age-in-days indicator on cards, automated tests, and a repeatable demo seed and reset.
