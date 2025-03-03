<script>
import { GlAvatar, GlFilteredSearchSuggestion } from '@gitlab/ui';

import createFlash from '~/flash';
import { __ } from '~/locale';

import { DEFAULT_LABEL_ANY } from '../constants';

import BaseToken from './base_token.vue';

export default {
  components: {
    BaseToken,
    GlAvatar,
    GlFilteredSearchSuggestion,
  },
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      authors: this.config.initialAuthors || [],
      defaultAuthors: this.config.defaultAuthors || [DEFAULT_LABEL_ANY],
      preloadedAuthors: [
        {
          id: gon.current_user_id,
          name: gon.current_user_fullname,
          username: gon.current_username,
          avatar_url: gon.current_user_avatar_url,
        },
      ],
      loading: false,
    };
  },
  methods: {
    getActiveAuthor(authors, currentValue) {
      return authors.find((author) => author.username.toLowerCase() === currentValue);
    },
    getAvatarUrl(author) {
      return author.avatarUrl || author.avatar_url;
    },
    fetchAuthorBySearchTerm(searchTerm) {
      this.loading = true;
      const fetchPromise = this.config.fetchPath
        ? this.config.fetchAuthors(this.config.fetchPath, searchTerm)
        : this.config.fetchAuthors(searchTerm);

      fetchPromise
        .then((res) => {
          // We'd want to avoid doing this check but
          // users.json and /groups/:id/members & /projects/:id/users
          // return response differently.
          this.authors = Array.isArray(res) ? res : res.data;
        })
        .catch(() =>
          createFlash({
            message: __('There was a problem fetching users.'),
          }),
        )
        .finally(() => {
          this.loading = false;
        });
    },
  },
};
</script>

<template>
  <base-token
    :token-config="config"
    :token-value="value"
    :token-active="active"
    :tokens-list-loading="loading"
    :token-values="authors"
    :fn-active-token-value="getActiveAuthor"
    :default-token-values="defaultAuthors"
    :preloaded-token-values="preloadedAuthors"
    :recent-token-values-storage-key="config.recentTokenValuesStorageKey"
    @fetch-token-values="fetchAuthorBySearchTerm"
  >
    <template #view="{ viewTokenProps: { inputValue, activeTokenValue } }">
      <gl-avatar
        v-if="activeTokenValue"
        :size="16"
        :src="getAvatarUrl(activeTokenValue)"
        shape="circle"
        class="gl-mr-2"
      />
      <span>{{ activeTokenValue ? activeTokenValue.name : inputValue }}</span>
    </template>
    <template #token-values-list="{ tokenValues }">
      <gl-filtered-search-suggestion
        v-for="author in tokenValues"
        :key="author.username"
        :value="author.username"
      >
        <div class="gl-display-flex">
          <gl-avatar :size="32" :src="getAvatarUrl(author)" />
          <div>
            <div>{{ author.name }}</div>
            <div>@{{ author.username }}</div>
          </div>
        </div>
      </gl-filtered-search-suggestion>
    </template>
  </base-token>
</template>
