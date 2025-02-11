<script>
import { GlLink, GlTable, GlDropdownItem, GlDropdown, GlIcon } from '@gitlab/ui';
import { last } from 'lodash';
import { numberToHumanSize } from '~/lib/utils/number_utils';
import { __ } from '~/locale';
import Tracking from '~/tracking';
import FileIcon from '~/vue_shared/components/file_icon.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';

export default {
  name: 'PackageFiles',
  components: {
    GlLink,
    GlTable,
    GlIcon,
    GlDropdown,
    GlDropdownItem,
    FileIcon,
    TimeAgoTooltip,
  },
  mixins: [Tracking.mixin()],
  props: {
    packageFiles: {
      type: Array,
      required: false,
      default: () => [],
    },
    canDelete: {
      type: Boolean,
      default: false,
      required: false,
    },
  },
  computed: {
    filesTableRows() {
      return this.packageFiles.map((pf) => ({
        ...pf,
        size: this.formatSize(pf.size),
        pipeline: last(pf.pipelines),
      }));
    },
    showCommitColumn() {
      return this.filesTableRows.some((row) => Boolean(row.pipeline?.id));
    },
    filesTableHeaderFields() {
      return [
        {
          key: 'name',
          label: __('Name'),
        },
        {
          key: 'commit',
          label: __('Commit'),
          hide: !this.showCommitColumn,
        },
        {
          key: 'size',
          label: __('Size'),
        },
        {
          key: 'created',
          label: __('Created'),
          class: 'gl-text-right',
        },
        {
          key: 'actions',
          label: '',
          hide: !this.canDelete,
          class: 'gl-text-right',
          tdClass: 'gl-w-4',
        },
      ].filter((c) => !c.hide);
    },
  },
  methods: {
    formatSize(size) {
      return numberToHumanSize(size);
    },
  },
  i18n: {
    deleteFile: __('Delete file'),
  },
};
</script>

<template>
  <div>
    <h3 class="gl-font-lg gl-mt-5">{{ __('Files') }}</h3>
    <gl-table
      :fields="filesTableHeaderFields"
      :items="filesTableRows"
      :tbody-tr-attr="{ 'data-testid': 'file-row' }"
    >
      <template #cell(name)="{ item }">
        <gl-link
          :href="item.download_path"
          class="gl-text-gray-500"
          data-testid="download-link"
          @click="$emit('download-file')"
        >
          <file-icon
            :file-name="item.file_name"
            css-classes="gl-relative file-icon"
            class="gl-mr-1 gl-relative"
          />
          <span>{{ item.file_name }}</span>
        </gl-link>
      </template>

      <template #cell(commit)="{ item }">
        <gl-link
          v-if="item.pipeline && item.pipeline.project"
          :href="item.pipeline.project.commit_url"
          class="gl-text-gray-500"
          data-testid="commit-link"
          >{{ item.pipeline.git_commit_message }}</gl-link
        >
      </template>

      <template #cell(created)="{ item }">
        <time-ago-tooltip :time="item.created_at" />
      </template>

      <template #cell(actions)="{ item }">
        <gl-dropdown category="tertiary" right>
          <template #button-content>
            <gl-icon name="ellipsis_v" />
          </template>
          <gl-dropdown-item data-testid="delete-file" @click="$emit('delete-file', item)">
            {{ $options.i18n.deleteFile }}
          </gl-dropdown-item>
        </gl-dropdown>
      </template>
    </gl-table>
  </div>
</template>
