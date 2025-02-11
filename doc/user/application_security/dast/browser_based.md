---
stage: Secure
group: Dynamic Analysis
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
type: reference, howto
---

# DAST browser-based crawler **(ULTIMATE)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/323423) in GitLab 13.12.

WARNING:
This product is an early access and is considered a [beta](https://about.gitlab.com/handbook/product/gitlab-the-product/#beta) feature.

GitLab DAST's new browser-based crawler is a crawl engine built by GitLab to test Single Page Applications (SPAs) and traditional web applications.
Due to the reliance of modern web applications on JavaScript, handling SPAs or applications that are dependent on JavaScript is paramount to ensuring proper coverage of an application for Dynamic Application Security Testing (DAST).

The browser-based crawler works by loading the target application into a specially-instrumented Chromium browser. A snapshot of the page is taken prior to a search to find any actions that a user might perform,
such as clicking on a link or filling in a form. For each action found, the crawler will execute it, take a new snapshot and determine what in the page changed from the previous snapshot.
Crawling continues by taking more snapshots and finding subsequent actions.

The benefit of crawling by following user actions in a browser is that the crawler can interact with the target application much like a real user would, identifying complex flows that traditional web crawlers don’t understand. This results in better coverage of the website.

Scanning a web application with both the browser-based crawler and GitLab DAST should provide greater coverage, compared with only GitLab DAST. The new crawler does not support API scanning or the DAST AJAX crawler.

## Enable browser-based crawler

The browser-based crawler is an extension to the GitLab DAST product. DAST should be included in the CI/CD configuration and the browser-based crawler enabled using CI/CD variables:

1. Ensure the DAST [prerequisites](index.md#prerequisites) are met.
1. Include the [DAST CI template](index.md#include-the-dast-template).
1. Set the target website using the `DAST_WEBSITE` CI/CD variable.
1. Set the CI/CD variable `DAST_BROWSER_SCAN` to `true`.

An example configuration might look like the following:

```yaml
include:
  - template: DAST.gitlab-ci.yml

dast:
  variables:
    DAST_WEBSITE: "https://example.com"
    DAST_BROWSER_SCAN: "true"
```

### Available CI/CD variables

The browser-based crawler can be configured using CI/CD variables.

| CI/CD variable                       | Type            | Example                           | Description |
|--------------------------------------| ----------------| --------------------------------- | ------------|
| `DAST_WEBSITE`                       | URL             | `http://www.site.com`             | The URL of the website to scan. |
| `DAST_BROWSER_SCAN`               | boolean         | `true`                            | Configures DAST to use the browser-based crawler engine. |
| `DAST_BROWSER_ALLOWED_HOSTS`      | List of strings | `site.com,another.com`            | Hostnames included in this variable are considered in scope when crawled. By default the `DAST_WEBSITE` hostname is included in the allowed hosts list. |
| `DAST_BROWSER_EXCLUDED_HOSTS`     | List of strings | `site.com,another.com`            | Hostnames included in this variable are considered excluded and connections are forcibly dropped. |
| `DAST_BROWSER_IGNORED_HOSTS`      | List of strings | `site.com,another.com`            | Hostnames included in this variable are accessed but not reported against. |
| `DAST_BROWSER_MAX_ACTIONS`        | number          | `10000`                           | The maximum number of actions that the crawler performs. For example, clicking a link, or filling a form.  |
| `DAST_BROWSER_MAX_DEPTH`          | number          | `10`                              | The maximum number of chained actions that the crawler takes. For example, `Click -> Form Fill -> Click` is a depth of three. |
| `DAST_BROWSER_NUMBER_OF_BROWSERS` | number          | `3`                               | The maximum number of concurrent browser instances to use. For shared runners on GitLab.com we recommended a maximum of three. Private runners with more resources may benefit from a higher number, but will likely produce little benefit after five to seven instances. |
| `DAST_BROWSER_COOKIES`            | dictionary      | `abtesting_group:3,region:locked` | A cookie name and value to be added to every request. |
| `DAST_BROWSER_LOG`                | List of strings | `brows:debug,auth:debug`          | A list of modules and their intended log level. |
| `DAST_AUTH_URL`                      | string          | `https://example.com/sign-in`     | The URL of page that hosts the sign-in form. |
| `DAST_USERNAME`                      | string          | `user123`                         | The username to enter into the username field on the sign-in HTML form. |
| `DAST_PASSWORD`                      | string          | `p@55w0rd`                        | The password to enter into the password field on the sign-in HTML form. |
| `DAST_USERNAME_FIELD`                | selector        | `id:user`                         | A selector describing the username field on the sign-in HTML form. |
| `DAST_PASSWORD_FIELD`                | selector        | `css:.password-field`             | A selector describing the password field on the sign-in HTML form. |
| `DAST_SUBMIT_FIELD`                  | selector        | `xpath://input[@value='Login']`   | A selector describing the element that when clicked submits the login form, or the password form of a multi-page login process. |
| `DAST_FIRST_SUBMIT_FIELD`            | selector        | `.submit`                         | A selector describing the element that when clicked submits the username form of a multi-page login process. |
| `DAST_BROWSER_AUTH_REPORT`           | boolean         | `true`                            | Used in combination with exporting the `gl-dast-debug-auth-report.html` artifact to aid in debugging authentication issues. |
| `DAST_AUTH_VERIFICATION_URL`                | URL      | `http://site.com/welcome`         | Verifies successful authentication by checking the URL once the login form has been submitted. |
| `DAST_BROWSER_AUTH_VERIFICATION_SELECTOR`   | selector | `css:.user-photo`                | Verifies successful authentication by checking for presence of a selector once the login form has been submitted. |
| `DAST_BROWSER_AUTH_VERIFICATION_LOGIN_FORM` | boolean  | `true`                            | Verifies successful authentication by checking for the lack of a login form once the login form has been submitted. |

The [DAST variables](index.md#available-cicd-variables) `SECURE_ANALYZERS_PREFIX`, `DAST_FULL_SCAN_ENABLED`, `DAST_AUTO_UPDATE_ADDONS`, `DAST_EXCLUDE_RULES`, `DAST_REQUEST_HEADERS`, `DAST_HTML_REPORT`, `DAST_MARKDOWN_REPORT`, `DAST_XML_REPORT`,
`DAST_INCLUDE_ALPHA_VULNERABILITIES`, `DAST_PATHS_FILE`, `DAST_PATHS`, `DAST_ZAP_CLI_OPTIONS`, and `DAST_ZAP_LOG_CONFIGURATION` are also compatible with browser-based crawler scans.   

#### Selectors

Selectors are used by CI/CD variables to specify the location of an element displayed on a page in a browser.
Selectors have the format `type`:`search string`. The crawler will search for the selector using the search string based on the type.

| Selector type | Example                            | Description |
| ------------- | ---------------------------------- | ----------- |
| `css`         | `css:.password-field`              | Searches for a HTML element having the supplied CSS selector. Selectors should be as specific as possible for performance reasons. |
| `id`          | `id:element`                       | Searches for an HTML element with the provided element ID. |
| `name`        | `name:element`                     | Searches for an HTML element with the provided element name. |
| `xpath`       | `xpath://input[@id="my-button"]/a` | Searches for a HTML element with the provided XPath. Note that XPath searches are expected to be less performant than other searches. |
| None provided | `a.click-me`                       | Defaults to searching using a CSS selector. |

##### Find selectors with Google Chrome

Chrome DevTools element selector tool is an effective way to find a selector.

1. Open Chrome and navigate to the page where you would like to find a selector, for example, the login page for your site.
1. Open the `Elements` tab in Chrome DevTools with the keyboard shortcut `Command + Shift + c` in macOS or `Ctrl + Shift + c` in Windows.
1. Select the `Select an element in the page to select it` tool.
   ![search-elements](img/dast_auth_browser_scan_search_elements.png)
1. Select the field on your page that you would like to know the selector for.
1. Once the tool is active, highlight a field you wish to view the details of.
   ![highlight](img/dast_auth_browser_scan_highlight.png)
1. Once highlighted, you can see the element's details, including attributes that would make a good candidate for a selector.

In this example, the `id="user_login"` appears to be a good candidate. You can use this as a selector as the DAST username field by setting `DAST_USERNAME_FIELD: "css:[id=user_login]"`, or more simply, `DAST_USERNAME_FIELD: "id:user_login"`.

##### Choose the right selector

Judicious choice of selector leads to a scan that is resilient to the application changing.

In order of preference, it is recommended to choose as selectors:

- `id` fields. These are generally unique on a page, and rarely change.
- `name` fields. These are generally unique on a page, and rarely change.
- `class` values specific to the field, such as the selector `"css:.username"` for the `username` class on the username field.   
- Presence of field specific data attributes, such as the selector, `"css:[data-username]"` when the `data-username` field has any value on the username field.
- Multiple `class` hierarchy values, such as the selector `"css:.login-form .username"` when there are multiple elements with class `username` but only one nested inside the element with the class `login-form`.   

When using selectors to locate specific fields we recommend you avoid searching on:

- Any `id`, `name`, `attribute`, `class` or `value` that is dynamically generated.
- Generic class names, such as `column-10` and `dark-grey`.
- XPath searches as they are less performant than other selector searches.
- Unscoped searches, such as those beginning with `css:*` and `xpath://*`.

## Vulnerability detection

While the browser-based crawler crawls modern web applications efficiently, vulnerability detection is still managed by the standard DAST/Zed Attack Proxy (ZAP) solution.

The crawler runs the target website in a browser with DAST/ZAP configured as the proxy server. This ensures that all requests and responses made by the browser are passively scanned by DAST/ZAP.
When running a full scan, active vulnerability checks executed by DAST/ZAP do not use a browser. This difference in how vulnerabilities are checked can cause issues that require certain features of the target website to be disabled to ensure the scan works as intended.

For example, for a target website that contains forms with Anti-CSRF tokens, a passive scan will scan as intended because the browser displays pages/forms as if a user is viewing the page.
However, active vulnerability checks run in a full scan will not be able to submit forms containing Anti-CSRF tokens. In such cases we recommend you disable Anti-CSRF tokens when running a full scan.

## Authentication

If your application hosts content only available to logged in users then you will likely get much higher crawl coverage of your application by configuring authentication.
We recommended you periodically confirm that authentication is still working as this tends to break over
time due to changes to the application.

Authentication supports single form logins, multi-step login forms, and authenticating to URLs outside of the configured target URL.

An example configuration that authenticates a user might look like the following:

```yaml
include:
  - template: DAST.gitlab-ci.yml

dast:
  variables:
    DAST_WEBSITE: "https://example.com"
    DAST_BROWSER_SCAN: "true"
    DAST_AUTH_URL: "https://login.example.com/"
    DAST_USERNAME: "admin"
    DAST_PASSWORD: "P@55w0rd!"
    DAST_USERNAME_FIELD: "name:username"
    DAST_PASSWORD_FIELD: "name:password"
    DAST_SUBMIT_FIELD: "css:button[type='submit']"
```  

### Log in using automatic detection of the login form

By providing a `DAST_USERNAME`, `DAST_PASSWORD`, and `DAST_AUTH_URL`, the browser-based crawler will attempt to authenticate to the
target application by locating the login form based on a determination about whether or not the form contains username or password fields.

Automatic detection is "best-effort", and depending on the application being scanned may provide either a resilient login experience or one that fails to authenticate the user.

Login process:

1. The `DAST_AUTH_URL` is loaded into the browser, and any forms on the page are located.
   1. If a form contains a username and password field, `DAST_USERNAME` and `DAST_PASSWORD` is inputted into the respective fields, the form submit button is clicked and the user is logged in.
   1. If a form contains only a username field, it is assumed that the login form is multi-step.
      1. The `DAST_USERNAME` is inputted into the username field and the form submit button is clicked.
      1. The subsequent pages loads where it is expected that a form exists and contains a password field. If found, `DAST_PASSWORD` is inputted, form submit button is clicked and the user is logged in.

### Log in using explicit selection of the login form

By providing a `DAST_USERNAME_FIELD`, `DAST_PASSWORD_FIELD`, and `DAST_SUBMIT_FIELD`, in addition to the fields required for automatic login,
the browser-based crawler will attempt to authenticate to the target application by locating the login form based on the selectors provided.
Most applications will benefit from this approach to authentication.

Login process:

1. The `DAST_AUTH_URL` is loaded into the browser, and any forms on the page are located.
   1. If the `DAST_FIRST_SUBMIT_FIELD` is not defined, then `DAST_USERNAME` is inputted into `DAST_USERNAME_FIELD`, `DAST_PASSWORD` is inputted into `DAST_PASSWORD_FIELD`, `DAST_SUBMIT_FIELD` is clicked and the user is logged in.
   1. If the `DAST_FIRST_SUBMIT_FIELD` is defined, then it is assumed that the login form is multi-step.
      1. The `DAST_USERNAME` is inputted into the `DAST_USERNAME_FIELD` field and the `DAST_FIRST_SUBMIT_FIELD` is clicked.
      1. The subsequent pages loads where the `DAST_PASSWORD` is inputted into the `DAST_PASSWORD_FIELD` field, the `DAST_SUBMIT_FIELD` is clicked and the user is logged in.

### Verifying successful login

Once the login form has been submitted, the browser-based crawler determines if the login was successful. Unsuccessful attempts at authentication cause the scan to halt.

Following the submission of the login form, authentication is determined to be unsuccessful when:

- A `400` or `500` series HTTP response status code is returned.
- A new cookie/browser storage value determined to be sufficiently random has not been set.

In addition to these checks, the user can configure their own verification checks.
Each of the following checks can be used in conjunction with one another, if none are configured by default the presence of a login form is checked.

#### Verifying based on the URL

When `DAST_AUTH_VERIFICATION_URL` is configured, the URL displayed in the browser tab post login form submission is directly compared to the URL in the CI/CD variable.
If these are not exactly the same, authentication is deemed to be unsuccessful.

For example:

```yaml
include:
  - template: DAST.gitlab-ci.yml

dast:
  variables:
    DAST_WEBSITE: "https://example.com"
    DAST_BROWSER_SCAN: "true"
    ...
    DAST_AUTH_VERIFICATION_URL: "https://example.com/user/welcome"
```  

#### Verify based on presence of an element

When `DAST_BROWSER_AUTH_VERIFICATION_SELECTOR` is configured, the page displayed in the browser tab is searched for an element described by the selector in the CI/CD variable.
If no element is found, authentication is deemed to be unsuccessful.

For example:

```yaml
include:
  - template: DAST.gitlab-ci.yml

dast:
  variables:
    DAST_WEBSITE: "https://example.com"
    DAST_BROWSER_SCAN: "true"
    ...
    DAST_BROWSER_AUTH_VERIFICATION_SELECTOR: "css:.welcome-user"
```  

#### Verify based on presence of a login form

When `DAST_BROWSER_AUTH_VERIFICATION_LOGIN_FORM` is configured, the page displayed in the browser tab is searched for a form that is detected to be a login form.
If any such form is found, authentication is deemed to be unsuccessful.

For example:

```yaml
include:
  - template: DAST.gitlab-ci.yml

dast:
  variables:
    DAST_WEBSITE: "https://example.com"
    DAST_BROWSER_SCAN: "true"
    ...
    DAST_BROWSER_AUTH_VERIFICATION_LOGIN_FORM: "true"
```  

### Configure the authentication debug output

It is often difficult to understand the cause of an authentication failure when running DAST in a CI/CD pipeline.
To assist users in debugging authentication issues, a debug report can be generated and saved as a job artifact.
This HTML report contains all steps the browser crawler took, along with HTTP requests and responses, the Document Object Model (DOM) and screenshots.

![dast-auth-report](img/dast_auth_report.jpg)

An example configuration where the authentication debug report is exported may look like the following:

```yaml
dast:
  variables:
    DAST_WEBSITE: "https://example.com"
    DAST_BROWSER_SCAN: "true"
    ...
    DAST_BROWSER_AUTH_REPORT: "true"
  artifacts:
    paths: [gl-dast-debug-auth-report.html]
```

## Managing scan time

It is expected that running the browser-based crawler will result in better coverage for many web applications, when compared to the normal GitLab DAST solution.
This can come at a cost of increased scan time.

You can manage the trade-off between coverage and scan time with the following measures:

- Limit the number of actions executed by the browser with the [variable](#available-cicd-variables) `DAST_BROWSER_MAX_ACTIONS`. The default is `10,000`.
- Limit the page depth that the browser-based crawler will check coverage on with the [variable](#available-cicd-variables) `DAST_BROWSER_MAX_DEPTH`. The crawler uses a breadth-first search strategy, so pages with smaller depth are crawled first. The default is `10`.
- Vertically scaling the runner and using a higher number of browsers with [variable](#available-cicd-variables) `DAST_BROWSER_NUMBER_OF_BROWSERS`. The default is `3`.

## Debugging scans using logging

Logging can be used to help you troubleshoot a scan.

The CI/CD variable `DAST_BROWSER_LOG` configures the logging level for particular modules of the crawler. Each module represents a component of the browser-based crawler and is separated so that debug logs can be configured just for the area of the crawler that requires further inspection. For more details, see [Crawler modules](#crawler-modules).

For example, the following job definition enables the browsing module and the authentication module to be logged in debug-mode:

```yaml
include:
  - template: DAST.gitlab-ci.yml

dast:
  variables:
    DAST_WEBSITE: "https://my.site.com"
    DAST_BROWSER_SCAN: "true"
    DAST_BROWSER_LOG: "brows:debug,auth:debug"
```

### Log message format

Log messages have the format `[time] [log level] [log module] [message] [additional properties]`. For example, the following log entry has level `INFO`, is part of the `CRAWL` log module, and has the message `Crawled path`.

```txt
2021-04-21T00:34:04.000 INF CRAWL Crawled path nav_id=0cc7fd path="LoadURL [https://my.site.com:8090]"
```

### Crawler modules

The modules that can be configured for logging are as follows:

| Log module | Component overview |
| ---------- | ----------- |
| `AUTH`     | Used for creating an authenticated scan. |
| `BROWS`    | Used for querying the state/page of the browser. |
| `BPOOL`    | The set of browsers that are leased out for crawling. |
| `CRAWL`    | Used for the core crawler algorithm. |
| `DATAB`    | Used for persisting data to the internal database. |
| `LEASE`    | Used to create browsers to add them to the browser pool. |
| `MAIN`     | Used for the flow of the main event loop of the crawler. |
| `NAVDB`    | Used for persistence mechanisms to store navigation entries. |
| `REPT`     | Used for generating reports. |
| `STAT`     | Used for general statistics while running the scan. |
