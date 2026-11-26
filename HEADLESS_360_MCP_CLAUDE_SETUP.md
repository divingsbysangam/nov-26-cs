# Connect Claude to Salesforce with the Headless 360 MCP Server

These are the steps we followed to connect Claude to a Salesforce Developer Edition org through the Headless 360 MCP Server, including the problem we hit and how it was resolved.

> **Status note:** the Headless 360 MCP Server is a beta service. Salesforce Multi-Framework (React apps on Salesforce) is generally available. Settings and screens can change, so trust what you see in your org.

## 1. Check the org

1. Use a Developer Edition org on Hyperforce.
2. In Setup, search for **Salesforce Multi-Framework Apps**. The page should say Multi-Framework is enabled and the **Salesforce App Domain** toggle should be **Active**.

## 2. Activate the Headless 360 MCP Server

1. In Setup, open **MCP Servers** (Salesforce Hosted MCP Servers).
2. Open **Headless360 (H360) MCP Server** and click **Activate**.
3. Copy the **Server URL** from the Authentication Details section. It is specific to your org. You need it in step 5.

The server exposes a small, stable set of tools (Discover, Describe, Dispatch and Dispatch Read Only). Every call runs as the authenticated user, so Claude can only do what that user is allowed to do.

## 3. Create an External Client App (ECA)

Use an External Client App. Connected Apps are not supported for hosted MCP servers.

**App Settings**

| Setting | Value |
| --- | --- |
| Enable OAuth | On |
| Callback URL | `https://claude.ai/api/mcp/auth_callback` |
| OAuth Scopes | `Perform requests at any time (refresh_token, offline_access)` and `Access Salesforce hosted MCP servers (mcp_api)` |
| Introspect all Tokens / Configure ID token | Off |

**Flow Enablement:** leave all flows unchecked. Claude signs in with the standard authorization code flow, which comes with Enable OAuth.

**Security**

| Setting | Value |
| --- | --- |
| Require PKCE for Supported Authorization Flows | On (locked by Salesforce) |
| Enable Refresh Token Rotation | On (locked by Salesforce) |
| Issue JSON Web Token (JWT)-based access tokens for named users | **On** |
| Require secret for Web Server Flow / Refresh Token Flow | Off |
| Enforce Refresh Token IP Allowlist, Require DPoP | Off |

**OAuth Policies**

| Setting | Value |
| --- | --- |
| Permitted Users | All users can self-authorize |
| IP Relaxation | Relax IP restrictions |

Save, then copy the **Consumer Key** (and Consumer Secret) from the **Consumer Key and Secret** button. Wait a couple of minutes for a new app to propagate.

## 4. Add the connector in Claude

1. In Claude, go to **Settings > Connectors > Add custom connector**.
2. Name it, for example `Headless 360`, and paste the **Server URL** from step 2.
3. Open **Advanced settings** and paste the Consumer Key as the **OAuth Client ID**. If a Client Secret field is shown, add the Consumer Secret.
4. Click **Connect** and sign in to the Developer Edition org when Salesforce asks.
5. The connector should show **Connected**.

## 5. Problem we hit, and the fix

**Symptom:** the sign-in completed, then Claude showed an authorization error saying the account was authorized but the integration rejected the credentials it had just issued.

**What we changed:** we aligned the ECA Security settings with the configuration that other users reported as working. The connector then showed Connected. We did not isolate which single setting was responsible, so treat the list as a set:

- **Issue JWT-based access tokens for named users** was off. We turned it on.
- **IP Relaxation** was on "Enforce IP restrictions". Relaxing it is recommended for a demo org.
- We saved, waited a few minutes, then disconnected and re-added the connector.

If you still see the error: confirm the server is activated, confirm the callback URL matches exactly, check Login History in Setup for the rejection reason, and check whether API Access Control is blocking the connection.

## 6. Verify the connection

1. In a new Claude chat, ask: `Using Headless 360, list my 5 most recent Cases.`
2. Our Developer Edition org had no Cases, so we loaded 30 synthetic Cases with Salesforce Inspector Reloaded (Data Import, object `Case`, action Insert, CSV input with the columns Subject, Description, Status, Priority and Origin).
3. Ask the same question again. Claude should now return Cases.

## 7. What this is used for in the workshop

With the connector working, Claude can inspect the org and load synthetic data while Claude Code builds a React Case pipeline app with the Salesforce Development plugin. The app is deployed as a Salesforce Multi-Framework UI bundle and opened from the App Launcher.

## Safety notes

- Use synthetic data only.
- Never commit the Consumer Key, Consumer Secret or any token to this repository.
- Test the setup in a Developer Edition org or sandbox before using any shared org.
