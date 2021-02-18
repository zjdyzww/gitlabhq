// This is a true violation of @gitlab/no-runtime-template-compiler, as it relies on
// app/views/projects/merge_requests/conflicts/components/_diff_file_editor.html.haml
// for its template.
/* eslint-disable no-param-reassign, @gitlab/no-runtime-template-compiler */

import { debounce } from 'lodash';
import Vue from 'vue';
import { deprecatedCreateFlash as flash } from '~/flash';
import axios from '~/lib/utils/axios_utils';
import { __ } from '~/locale';

((global) => {
  global.mergeConflicts = global.mergeConflicts || {};

  global.mergeConflicts.diffFileEditor = Vue.extend({
    props: {
      file: {
        type: Object,
        required: true,
      },
      onCancelDiscardConfirmation: {
        type: Function,
        required: true,
      },
      onAcceptDiscardConfirmation: {
        type: Function,
        required: true,
      },
    },
    data() {
      return {
        saved: false,
        fileLoaded: false,
        originalContent: '',
      };
    },
    computed: {
      classObject() {
        return {
          saved: this.saved,
        };
      },
    },
    watch: {
      'file.showEditor': function showEditorWatcher(val) {
        this.resetEditorContent();

        if (!val || this.fileLoaded) {
          return;
        }

        this.loadEditor();
      },
    },
    mounted() {
      if (this.file.loadEditor) {
        this.loadEditor();
      }
    },
    methods: {
      loadEditor() {
        const EditorPromise = import(/* webpackChunkName: 'EditorLite' */ '~/editor/editor_lite');
        const DataPromise = axios.get(this.file.content_path);

        Promise.all([EditorPromise, DataPromise])
          .then(
            ([
              { default: EditorLite },
              {
                data: { content, new_path: path },
              },
            ]) => {
              const contentEl = this.$el.querySelector('.editor');

              this.originalContent = content;
              this.fileLoaded = true;

              this.editor = new EditorLite().createInstance({
                el: contentEl,
                blobPath: path,
                blobContent: content,
              });
              this.editor.onDidChangeModelContent(
                debounce(this.saveDiffResolution.bind(this), 250),
              );
            },
          )
          .catch(() => {
            flash(__('An error occurred while loading the file'));
          });
      },
      saveDiffResolution() {
        this.saved = true;

        // This probably be better placed in the data provider
        /* eslint-disable vue/no-mutating-props */
        this.file.content = this.editor.getValue();
        this.file.resolveEditChanged = this.file.content !== this.originalContent;
        this.file.promptDiscardConfirmation = false;
        /* eslint-enable vue/no-mutating-props */
      },
      resetEditorContent() {
        if (this.fileLoaded) {
          this.editor.setValue(this.originalContent);
        }
      },
      cancelDiscardConfirmation(file) {
        this.onCancelDiscardConfirmation(file);
      },
      acceptDiscardConfirmation(file) {
        this.onAcceptDiscardConfirmation(file);
      },
    },
  });
})(window.gl || (window.gl = {}));
