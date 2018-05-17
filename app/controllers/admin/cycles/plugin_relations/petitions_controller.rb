class Admin::Cycles::PluginRelations::PetitionsController < Admin::ApplicationController
  def index
    @petition = @plugin_relation.petition_detail
    dynamic_link_metrics = get_dynamic_link_metrics @petition
    if dynamic_link_metrics
      android_metrics = dynamic_link_metrics.select { |metric| metric.platform == "ANDROID"}
      @android_metrics_with_default = add_defaults_to_dynamic_link_metrics android_metrics, "ANDROID"
      ios_metrics = dynamic_link_metrics.select { |metric| metric.platform == "IOS"}
      @ios_metrics_with_default = add_defaults_to_dynamic_link_metrics ios_metrics, "IOS"
      other_metrics = dynamic_link_metrics.select { |metric| metric.platform == "OTHER"}
      @other_metrics_with_default = add_defaults_to_dynamic_link_metrics other_metrics, "OTHER"
    end
  end

  def new
    @petition = PetitionPlugin::Detail.new
  end

  def edit
    @petition = @plugin_relation.petition_detail
  end

  def update
    @petition = @plugin_relation.petition_detail

    response = detail_updater.perform @petition, petition_params, petition_body
    if response.success
      enqueue_pdf_generation response
      flash[:success] = "Projeto de Lei salvo com sucesso."
      redirect_to [:admin, @cycle, @plugin_relation, :petitions]
    else
      flash[:error] = "Ocorreu algum erro ao atualizar o Projeto de Lei."
      render :edit
    end
  end

  def create
    if @plugin_relation.petition_detail
      flash[:error] = "Esta petição já foi salva por outra pessoa, tente novamente clicando em Editar Projeto de Lei"
      return redirect_to [:admin, @cycle, @plugin_relation, :petitions]
    end

    @petition = PetitionPlugin::Detail.new(plugin_relation_id: @plugin_relation.id)

    response = detail_updater.perform @petition, petition_params, petition_body
    if response.success
      shared_link_generation response
      enqueue_pdf_generation response
      flash[:success] = "Projeto de Lei salvo com sucesso."
      redirect_to [:admin, @cycle, @plugin_relation, :petitions]
    else
      flash[:error] = "Ocorreu algum erro ao criar a petição."
      render :new
    end
  end

  helper_method :past_versions
  def past_versions
    detail_repository.past_versions_desc(@petition.id)
  end

  private

  def detail_repository
    @detail_repository ||= PetitionPlugin::DetailRepository.new
  end

  def petition_params
    params.require(:petition_plugin_detail)
      .permit(%i(
        call_to_action
        initial_signatures_goal
        signatures_required
        presentation
        video_id
        scope_coverage
        city_id
        uf
      ))
  end

  def petition_body
    params.require(:petition_plugin_detail).require(:current_version).permit(:body)[:body]
  end

  def enqueue_pdf_generation(use_case_response)
    PetitionPdfGenerationWorker.perform_async id: use_case_response.version.id if use_case_response.version
  end

  def shared_link_generation(response)
    PetitionShareLinkGenerationWorker.perform_async id: response.detail.id
  end

  def get_dynamic_link_metrics(petition)
    metricsShareLinkService = ShareLinkMetricsService.new
    metricsShareLinkService.getMetrics petition.share_link, 30
  end

  def add_defaults_to_dynamic_link_metrics(metrics, platform)
    metrics_with_defaults = []
    metrics_with_defaults << get_metric_with_default(metrics, "CLICK", platform)
    metrics_with_defaults << get_metric_with_default(metrics, "REDIRECT", platform)
    metrics_with_defaults << get_metric_with_default(metrics, "APP_INSTALL", platform)
    metrics_with_defaults << get_metric_with_default(metrics, "APP_FIRST_OPEN", platform)
    metrics_with_defaults << get_metric_with_default(metrics, "APP_RE_OPEN", platform)

    metrics_with_defaults
  end

  def get_metric_with_default(metrics, event, platform)
    metric = metrics.select { |metric| metric.event == event }
    metric.any? ? metric.first : OpenStruct.new(:count => "0", :event => event, :platform => platform)
  end

  def detail_updater
    @detail_updater ||= PetitionPlugin::DetailUpdater.new
  end
end
