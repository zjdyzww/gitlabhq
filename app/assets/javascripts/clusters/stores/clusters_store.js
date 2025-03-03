import { parseBoolean } from '../../lib/utils/common_utils';
import { s__ } from '../../locale';
import {
  INGRESS,
  JUPYTER,
  KNATIVE,
  CERT_MANAGER,
  CROSSPLANE,
  RUNNER,
  APPLICATION_INSTALLED_STATUSES,
  APPLICATION_STATUS,
  INSTALL_EVENT,
  UPDATE_EVENT,
  UNINSTALL_EVENT,
  ELASTIC_STACK,
  FLUENTD,
} from '../constants';
import transitionApplicationState from '../services/application_state_machine';

const isApplicationInstalled = (appStatus) => APPLICATION_INSTALLED_STATUSES.includes(appStatus);

const applicationInitialState = {
  status: null,
  statusReason: null,
  requestReason: null,
  installable: true,
  installed: false,
  installFailed: false,
  uninstallable: false,
  uninstallFailed: false,
  uninstallSuccessful: false,
  validationError: null,
};

export default class ClusterStore {
  constructor() {
    this.state = {
      helpPath: null,
      helmHelpPath: null,
      ingressHelpPath: null,
      environmentsHelpPath: null,
      clustersHelpPath: null,
      deployBoardsHelpPath: null,
      cloudRunHelpPath: null,
      status: null,
      providerType: null,
      preInstalledKnative: false,
      rbac: false,
      statusReason: null,
      applications: {
        helm: {
          ...applicationInitialState,
          title: s__('ClusterIntegration|Legacy Helm Tiller server'),
        },
        ingress: {
          ...applicationInitialState,
          title: s__('ClusterIntegration|Ingress'),
          externalIp: null,
          externalHostname: null,
          updateFailed: false,
          updateAvailable: false,
        },
        cert_manager: {
          ...applicationInitialState,
          title: s__('ClusterIntegration|Cert-Manager'),
          email: null,
        },
        crossplane: {
          ...applicationInitialState,
          title: s__('ClusterIntegration|Crossplane'),
          stack: null,
        },
        runner: {
          ...applicationInitialState,
          title: s__('ClusterIntegration|GitLab Runner'),
          version: null,
          chartRepo: 'https://gitlab.com/gitlab-org/charts/gitlab-runner',
          updateAvailable: null,
          updateSuccessful: false,
          updateFailed: false,
        },
        prometheus: {
          ...applicationInitialState,
          title: s__('ClusterIntegration|Prometheus'),
        },
        jupyter: {
          ...applicationInitialState,
          title: s__('ClusterIntegration|JupyterHub'),
          hostname: null,
        },
        knative: {
          ...applicationInitialState,
          title: s__('ClusterIntegration|Knative'),
          hostname: null,
          isEditingDomain: false,
          externalIp: null,
          externalHostname: null,
          updateSuccessful: false,
          updateFailed: false,
        },
        elastic_stack: {
          ...applicationInitialState,
          title: s__('ClusterIntegration|Elastic Stack'),
        },
        fluentd: {
          ...applicationInitialState,
          title: s__('ClusterIntegration|Fluentd'),
          host: null,
          port: null,
          protocol: null,
          ciliumLogEnabled: null,
          isEditingSettings: false,
        },
        cilium: {
          ...applicationInitialState,
          title: s__('ClusterIntegration|GitLab Container Network Policies'),
          installable: false,
        },
      },
      environments: [],
      fetchingEnvironments: false,
    };
  }

  setHelpPaths(helpPaths) {
    Object.assign(this.state, {
      ...helpPaths,
    });
  }

  setManagePrometheusPath(managePrometheusPath) {
    this.state.managePrometheusPath = managePrometheusPath;
  }

  updateStatus(status) {
    this.state.status = status;
  }

  updateProviderType(providerType) {
    this.state.providerType = providerType;
  }

  updatePreInstalledKnative(preInstalledKnative) {
    this.state.preInstalledKnative = parseBoolean(preInstalledKnative);
  }

  updateRbac(rbac) {
    this.state.rbac = parseBoolean(rbac);
  }

  updateStatusReason(reason) {
    this.state.statusReason = reason;
  }

  installApplication(appId) {
    this.handleApplicationEvent(appId, INSTALL_EVENT);
  }

  notifyInstallFailure(appId) {
    this.handleApplicationEvent(appId, APPLICATION_STATUS.ERROR);
  }

  updateApplication(appId) {
    this.handleApplicationEvent(appId, UPDATE_EVENT);
  }

  notifyUpdateFailure(appId) {
    this.handleApplicationEvent(appId, APPLICATION_STATUS.UPDATE_ERRORED);
  }

  uninstallApplication(appId) {
    this.handleApplicationEvent(appId, UNINSTALL_EVENT);
  }

  notifyUninstallFailure(appId) {
    this.handleApplicationEvent(appId, APPLICATION_STATUS.UNINSTALL_ERRORED);
  }

  handleApplicationEvent(appId, event) {
    const currentAppState = this.state.applications[appId];

    this.state.applications[appId] = transitionApplicationState(currentAppState, event);
  }

  updateAppProperty(appId, prop, value) {
    this.state.applications[appId][prop] = value;
  }

  updateStateFromServer(serverState = {}) {
    this.state.status = serverState.status;
    this.state.statusReason = serverState.status_reason;

    serverState.applications.forEach((serverAppEntry) => {
      const {
        name: appId,
        status,
        status_reason: statusReason,
        version,
        update_available: updateAvailable,
        can_uninstall: uninstallable,
      } = serverAppEntry;
      const currentApplicationState = this.state.applications[appId] || {};
      const nextApplicationState = transitionApplicationState(currentApplicationState, status);

      this.state.applications[appId] = {
        ...currentApplicationState,
        ...nextApplicationState,
        statusReason,
        installed: isApplicationInstalled(nextApplicationState.status),
        uninstallable,
      };

      if (appId === INGRESS) {
        this.state.applications.ingress.externalIp = serverAppEntry.external_ip;
        this.state.applications.ingress.externalHostname = serverAppEntry.external_hostname;
        this.state.applications.ingress.updateAvailable = updateAvailable;
      } else if (appId === CERT_MANAGER) {
        this.state.applications.cert_manager.email =
          this.state.applications.cert_manager.email || serverAppEntry.email;
      } else if (appId === CROSSPLANE) {
        this.state.applications.crossplane.stack =
          this.state.applications.crossplane.stack || serverAppEntry.stack;
      } else if (appId === JUPYTER) {
        this.state.applications.jupyter.hostname = this.updateHostnameIfUnset(
          this.state.applications.jupyter.hostname,
          serverAppEntry.hostname,
          'jupyter',
        );
      } else if (appId === KNATIVE) {
        if (serverAppEntry.available_domains) {
          this.state.applications.knative.availableDomains = serverAppEntry.available_domains;
        }
        if (!this.state.applications.knative.isEditingDomain) {
          this.state.applications.knative.pagesDomain =
            serverAppEntry.pages_domain || this.state.applications.knative.pagesDomain;
          this.state.applications.knative.hostname =
            serverAppEntry.hostname || this.state.applications.knative.hostname;
        }
        this.state.applications.knative.externalIp =
          serverAppEntry.external_ip || this.state.applications.knative.externalIp;
        this.state.applications.knative.externalHostname =
          serverAppEntry.external_hostname || this.state.applications.knative.externalHostname;
      } else if (appId === RUNNER) {
        this.state.applications.runner.version = version;
        this.state.applications.runner.updateAvailable = updateAvailable;
      } else if (appId === ELASTIC_STACK) {
        this.state.applications.elastic_stack.version = version;
        this.state.applications.elastic_stack.updateAvailable = updateAvailable;
      } else if (appId === FLUENTD) {
        if (!this.state.applications.fluentd.isEditingSettings) {
          this.state.applications.fluentd.port = serverAppEntry.port;
          this.state.applications.fluentd.host = serverAppEntry.host;
          this.state.applications.fluentd.protocol = serverAppEntry.protocol;
          this.state.applications.fluentd.ciliumLogEnabled = serverAppEntry.cilium_log_enabled;
        }
      }
    });
  }

  updateHostnameIfUnset(current, updated, fallback) {
    return (
      current ||
      updated ||
      (this.state.applications.ingress.externalIp
        ? `${fallback}.${this.state.applications.ingress.externalIp}.nip.io`
        : '')
    );
  }

  toggleFetchEnvironments(isFetching) {
    this.state.fetchingEnvironments = isFetching;
  }

  updateEnvironments(environments = []) {
    this.state.environments = environments.map((environment) => ({
      name: environment.name,
      project: environment.project,
      environmentPath: environment.environment_path,
      logsPath: environment.logs_path,
      lastDeployment: environment.last_deployment,
      rolloutStatus: {
        status: environment.rollout_status ? environment.rollout_status.status : null,
        instances: environment.rollout_status ? environment.rollout_status.instances : [],
      },
      updatedAt: environment.updated_at,
    }));
  }
}
