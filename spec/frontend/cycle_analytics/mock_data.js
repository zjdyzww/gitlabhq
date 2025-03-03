import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';

export const getStageByTitle = (stages, title) =>
  stages.find((stage) => stage.title && stage.title.toLowerCase().trim() === title) || {};

export const defaultStages = ['issue', 'plan', 'review', 'code', 'test', 'staging'];

export const summary = [
  { value: '20', title: 'New Issues' },
  { value: null, title: 'Commits' },
  { value: null, title: 'Deploys' },
  { value: null, title: 'Deployment Frequency', unit: 'per day' },
];

const issueStage = {
  id: 'issue',
  title: 'Issue',
  name: 'issue',
  legend: '',
  description: 'Time before an issue gets scheduled',
  value: null,
};

const planStage = {
  id: 'plan',
  title: 'Plan',
  name: 'plan',
  legend: '',
  description: 'Time before an issue starts implementation',
  value: 75600,
};

const codeStage = {
  id: 'code',
  title: 'Code',
  name: 'code',
  legend: '',
  description: 'Time until first merge request',
  value: 172800,
};

const testStage = {
  id: 'test',
  title: 'Test',
  name: 'test',
  legend: '',
  description: 'Total test time for all commits/merges',
  value: 17550,
};

const reviewStage = {
  id: 'review',
  title: 'Review',
  name: 'review',
  legend: '',
  description: 'Time between merge request creation and merge/close',
  value: null,
};

const stagingStage = {
  id: 'staging',
  title: 'Staging',
  name: 'staging',
  legend: '',
  description: 'From merge request merge until deploy to production',
  value: 172800,
};

export const selectedStage = {
  ...issueStage,
  value: null,
  active: false,
  isUserAllowed: true,
  emptyStageText:
    'The issue stage shows the time it takes from creating an issue to assigning the issue to a milestone, or add the issue to a list on your Issue Board. Begin creating issues to see data for this stage.',
  component: 'stage-issue-component',
  slug: 'issue',
};

export const stats = [issueStage, planStage, codeStage, testStage, reviewStage, stagingStage];

export const permissions = {
  issue: true,
  plan: true,
  code: true,
  test: true,
  review: true,
  staging: true,
};

export const rawData = {
  summary,
  stats,
  permissions,
};

export const convertedData = {
  stages: [
    selectedStage,
    {
      ...planStage,
      active: false,
      isUserAllowed: true,
      emptyStageText:
        'The planning stage shows the time from the previous step to pushing your first commit. This time will be added automatically once you push your first commit.',
      component: 'stage-plan-component',
      slug: 'plan',
    },
    {
      ...codeStage,
      active: false,
      isUserAllowed: true,
      emptyStageText:
        'The coding stage shows the time from the first commit to creating the merge request. The data will automatically be added here once you create your first merge request.',
      component: 'stage-code-component',
      slug: 'code',
    },
    {
      ...testStage,
      active: false,
      isUserAllowed: true,
      emptyStageText:
        'The testing stage shows the time GitLab CI takes to run every pipeline for the related merge request. The data will automatically be added after your first pipeline finishes running.',
      component: 'stage-test-component',
      slug: 'test',
    },
    {
      ...reviewStage,
      active: false,
      isUserAllowed: true,
      emptyStageText:
        'The review stage shows the time from creating the merge request to merging it. The data will automatically be added after you merge your first merge request.',
      component: 'stage-review-component',
      slug: 'review',
    },
    {
      ...stagingStage,
      active: false,
      isUserAllowed: true,
      emptyStageText:
        'The staging stage shows the time between merging the MR and deploying code to the production environment. The data will be automatically added once you deploy to production for the first time.',
      component: 'stage-staging-component',
      slug: 'staging',
    },
  ],
  summary: [
    { value: '20', title: 'New Issues' },
    { value: '-', title: 'Commits' },
    { value: '-', title: 'Deploys' },
    { value: '-', title: 'Deployment Frequency', unit: 'per day' },
  ],
};

export const rawEvents = [
  {
    title: 'Brockfunc-1617160796',
    author: {
      id: 275,
      name: 'VSM User4',
      username: 'vsm-user-4-1617160796',
      state: 'active',
      avatar_url:
        'https://www.gravatar.com/avatar/6a6f5480ae582ba68982a34169420747?s=80&d=identicon',
      web_url: 'http://gdk.test:3001/vsm-user-4-1617160796',
      show_status: false,
      path: '/vsm-user-4-1617160796',
    },
    iid: '16',
    total_time: { days: 1, hours: 9 },
    created_at: 'about 1 month ago',
    url: 'http://gdk.test:3001/vsa-life/ror-project-vsa/-/issues/16',
    short_sha: 'some_sha',
    commit_url: 'some_commit_url',
  },
  {
    title: 'Subpod-1617160796',
    author: {
      id: 274,
      name: 'VSM User3',
      username: 'vsm-user-3-1617160796',
      state: 'active',
      avatar_url:
        'https://www.gravatar.com/avatar/fde853fc3ab7dc552e649dcb4fcf5f7f?s=80&d=identicon',
      web_url: 'http://gdk.test:3001/vsm-user-3-1617160796',
      show_status: false,
      path: '/vsm-user-3-1617160796',
    },
    iid: '20',
    total_time: { days: 2, hours: 18 },
    created_at: 'about 1 month ago',
    url: 'http://gdk.test:3001/vsa-life/ror-project-vsa/-/issues/20',
  },
];

export const convertedEvents = rawEvents.map((ev) =>
  convertObjectPropsToCamelCase(ev, { deep: true }),
);

export const pathNavIssueMetric = 172800;

export const rawStageMedians = [
  { id: 'issue', value: 172800 },
  { id: 'plan', value: 86400 },
  { id: 'review', value: 1036800 },
  { id: 'code', value: 129600 },
  { id: 'test', value: 259200 },
  { id: 'staging', value: 388800 },
];

export const stageMedians = {
  issue: 172800,
  plan: 86400,
  review: 1036800,
  code: 129600,
  test: 259200,
  staging: 388800,
};

export const allowedStages = [issueStage, planStage, codeStage];

export const transformedProjectStagePathData = [
  {
    metric: 172800,
    selected: true,
    stageCount: undefined,
    icon: null,
    id: 'issue',
    title: 'Issue',
    name: 'issue',
    legend: '',
    description: 'Time before an issue gets scheduled',
    value: null,
  },
  {
    metric: 86400,
    selected: false,
    stageCount: undefined,
    icon: null,
    id: 'plan',
    title: 'Plan',
    name: 'plan',
    legend: '',
    description: 'Time before an issue starts implementation',
    value: 75600,
  },
  {
    metric: 129600,
    selected: false,
    stageCount: undefined,
    icon: null,
    id: 'code',
    title: 'Code',
    name: 'code',
    legend: '',
    description: 'Time until first merge request',
    value: 172800,
  },
];
