---
stage: none
group: unassigned
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Export Issues to CSV

> Moved to GitLab Free in 12.10.

Issues can be exported as CSV from GitLab and are sent to your default notification email as an attachment.

## Overview

**Export Issues to CSV** enables you and your team to export all the data collected from issues into
a **[comma-separated values](https://en.wikipedia.org/wiki/Comma-separated_values)** (CSV) file,
which stores tabular data in plain text.

> _CSVs are a handy way of getting data from one program to another where one program cannot read the other ones normal output._ [Ref](https://www.quora.com/What-is-a-CSV-file-and-its-uses)

CSV files can be used with any plotter or spreadsheet-based program, such as Microsoft Excel,
Open Office <!-- vale gitlab.Spelling = NO --> Calc, <!-- vale gitlab.Spelling = NO --> or Google Spreadsheets.

## Use cases

Among numerous use cases for exporting issues for CSV, we can name a few:

- Make a snapshot of issues for offline analysis or to communicate with other teams who may not be in GitLab
- Create diagrams, graphs, and charts from the CSV data
- Present the data in any other format for auditing or sharing reasons
- Import the issues elsewhere to a system outside of GitLab
- Long-term issues' data analysis with multiple snapshots created along the time
- Use the long-term data to gather relevant feedback given in the issues, and improve your product based on real metrics

## Choosing which issues to include

After selecting a project, from the issues page you can narrow down which issues to export using the search bar, along with the All/Open/Closed tabs. All issues returned are exported, including those not shown on the first page.

![CSV export button](img/csv_export_button_v12_9.png)

GitLab asks you to confirm the number of issues and email address for the export, after which the email is prepared.

![CSV export modal dialog](img/csv_export_modal.png)

## Sorting

Exported issues are always sorted by `Issue ID`.

## Format

Data is encoded with a comma as the column delimiter, with `"` used to quote fields if needed, and newlines to separate rows. The first row contains the headers, which are listed in the following table along with a description of the values:

| Column  | Description |
|---------|-------------|
| Issue ID | Issue `iid` |
| URL | A link to the issue on GitLab |
| Title | Issue `title` |
| State | `Open` or `Closed` |
| Description | Issue `description` |
| Author | Full name of the issue author |
| Author Username | Username of the author, with the `@` symbol omitted |
| Assignee | Full name of the issue assignee |
| Assignee Username | Username of the author, with the `@` symbol omitted |
| Confidential | `Yes` or `No` |
| Locked | `Yes` or `No` |
| Due Date | Formatted as `YYYY-MM-DD` |
| Created At (UTC) | Formatted as `YYYY-MM-DD HH:MM:SS` |
| Updated At (UTC) | Formatted as `YYYY-MM-DD HH:MM:SS` |
| Milestone | Title of the issue milestone |
| Weight | Issue weight |
| Labels | Title of any labels joined with a `,` |
| Time Estimate | [Time estimate](../time_tracking.md#estimates) in seconds |
| Time Spent | [Time spent](../time_tracking.md#time-spent) in seconds |
| Epic ID | ID of the parent epic **(ULTIMATE)**, introduced in 12.7 |
| Epic Title | Title of the parent epic **(ULTIMATE)**, introduced in 12.7 |

## Limitations

- Export Issues to CSV is not available at the Group's Issues List.
- As the issues are sent as an email attachment, there is a limit on how much data can be exported. Currently this limit is 15MB to ensure successful delivery across a range of email providers. If this limit is reached we suggest narrowing the search before export, perhaps by exporting open and closed issues separately.
- As CSV files are plain text files, this means that the exported CSV file does not contain any attachments that have been added to an issue.
