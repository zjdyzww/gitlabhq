---
type: howto
stage: Manage
group: Access
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Enforce Two-factor Authentication (2FA)

Two-factor Authentication (2FA) provides an additional level of security to your
users' GitLab account. After being enabled, in addition to supplying their
username and password to sign in, they'll be prompted for a code generated by an
application on their phone.

You can read more about it here:
[Two-factor Authentication (2FA)](../user/profile/account/two_factor_authentication.md)

## Enforcing 2FA for all users

Users on GitLab can enable it without any administrator's intervention. If you
want to enforce everyone to set up 2FA, you can choose from two different ways:

- Enforce on next login.
- Suggest on next login, but allow a grace period before enforcing.

After the configured grace period has elapsed, users can sign in but
cannot leave the 2FA configuration area at `/profile/two_factor_auth`.

To enable 2FA for all users:

1. Navigate to **Admin Area > Settings > General**
   (`/admin/application_settings/general`).
1. Expand the **Sign-in restrictions** section, where you can configure both.

If you want 2FA enforcement to take effect during the next sign-in attempt,
change the grace period to `0`.

## Enforcing 2FA for all users in a group

> [Introduced in](https://gitlab.com/gitlab-org/gitlab-foss/-/merge_requests/24965) GitLab 12.0, 2FA settings for a group are also applied to subgroups.

If you want to enforce 2FA only for certain groups, you can:

1. Enable it in the group's **Settings > General** page. Navigate to
   **Permissions, LFS, 2FA > Two-factor authentication**. You can then select
   the **Require all users in this group to setup Two-factor authentication**
   option.
1. You can also specify a grace period in the **Time before enforced** option.

To change this setting, you need to be administrator or owner of the group.

If you want to enforce 2FA only for certain groups, you can enable it in the
group settings and specify a grace period as above. To change this setting you
need to be administrator or owner of the group.

The following are important notes about 2FA:

- Projects belonging to a 2FA-enabled group that
  [is shared](../user/project/members/share_project_with_groups.md)
  with a 2FA-disabled group will *not* require members of the 2FA-disabled group to use
  2FA for the project. For example, if project *P* belongs to 2FA-enabled group *A* and
  is shared with 2FA-disabled group *B*, members of group *B* can access project *P*
  without 2FA. To ensure this scenario doesn't occur,
  [prevent sharing of projects](../user/group/index.md#prevent-a-project-from-being-shared-with-groups)
  for the 2FA-enabled group.
- If you add additional members to a project within a group or subgroup that has
  2FA enabled, 2FA is **not** required for those individually added members.
- If there are multiple 2FA requirements (for example, group + all users, or multiple
  groups) the shortest grace period is used.
- It is possible to disallow subgroups from setting up their own 2FA requirements.
  Navigate to the top-level group's **Settings > General > Permissions, LFS, 2FA > Two-factor authentication** and uncheck the **Allow subgroups to set up their own two-factor authentication rule** field. This action causes all subgroups with 2FA requirements to stop requiring that from their members.

## Disabling 2FA for everyone

WARNING:
Disabling 2FA for everyone does not disable the [enforce 2FA for all users](#enforcing-2fa-for-all-users)
or [enforce 2FA for all users in a group](#enforcing-2fa-for-all-users-in-a-group)
settings. In addition to the steps in this section, you must disable any enforced 2FA
settings so users aren't asked to set up 2FA again, the next time the user signs in to GitLab.

There may be some special situations where you want to disable 2FA for everyone
even when forced 2FA is disabled. There is a Rake task for that:

```shell
# Omnibus installations
sudo gitlab-rake gitlab:two_factor:disable_for_all_users

# Installations from source
sudo -u git -H bundle exec rake gitlab:two_factor:disable_for_all_users RAILS_ENV=production
```

WARNING:
This is a permanent and irreversible action. Users have to
reactivate 2FA from scratch if they want to use it again.

<!-- ## Troubleshooting

Include any troubleshooting steps that you can foresee. If you know beforehand what issues
one might have when setting this up, or when something is changed, or on upgrading, it's
important to describe those, too. Think of things that may go wrong and include them here.
This is important to minimize requests for support, and to avoid doc comments with
questions that you know someone might ask.

Each scenario can be a third-level heading, e.g. `### Getting error message X`.
If you have none to add when creating a doc, leave this section in place
but commented out to help encourage others to add to it in the future. -->

## Two-factor Authentication (2FA) for Git over SSH operations **(PREMIUM)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/270554) in GitLab 13.7.
> - [Moved](https://gitlab.com/gitlab-org/gitlab/-/issues/299088) from GitLab Free to GitLab Premium in 13.9.
> - It's [deployed behind a feature flag](../user/feature_flags.md), disabled by default.
> - It's disabled on GitLab.com.
> - It's not recommended for production use.
> - To use it in GitLab self-managed instances, ask a GitLab administrator to [enable it](#enable-or-disable-two-factor-authentication-2fa-for-git-operations).

WARNING:
This feature might not be available to you. Check the **version history** note above for details.

Two-factor authentication can be enforced for Git over SSH operations. The OTP
verification can be done via a GitLab Shell command:

```shell
ssh git@<hostname> 2fa_verify
```

Once the OTP is verified, Git over SSH operations can be used for a session duration of
15 minutes (default) with the associated SSH key.

### Security limitation

2FA does not protect users with compromised *private* SSH keys.

Once an OTP is verified, anyone can run Git over SSH with that private SSH key for
the configured [session duration](../user/admin_area/settings/account_and_limit_settings.md#customize-session-duration-for-git-operations-when-2fa-is-enabled).

### Enable or disable Two-factor Authentication (2FA) for Git operations

Two-factor Authentication (2FA) for Git operations is under development and not
ready for production use. It is deployed behind a feature flag that is
**disabled by default**. [GitLab administrators with access to the GitLab Rails console](../administration/feature_flags.md)
can enable it.

To enable it:

```ruby
Feature.enable(:two_factor_for_cli)
```

To disable it:

```ruby
Feature.disable(:two_factor_for_cli)
```

The feature flag affects these features:

- [Two-factor Authentication (2FA) for Git over SSH operations](#two-factor-authentication-2fa-for-git-over-ssh-operations).
- [Customize session duration for Git Operations when 2FA is enabled](../user/admin_area/settings/account_and_limit_settings.md#customize-session-duration-for-git-operations-when-2fa-is-enabled).
