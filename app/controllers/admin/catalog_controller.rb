class Admin::CatalogController < Admin::BaseController
  before_action :set_record, only: %i[ edit update destroy ]
  helper_method :catalog_path, :catalog_name

  def index
    scope = self.class::MODEL.order(:id)
    scope = scope.with_attached_image if self.class::MODEL == BrainrotType
    @records = paginate(scope)
    @used_type_ids = BrainrotCard.where(brainrot_type_id: @records.map(&:id)).distinct.pluck(:brainrot_type_id) if self.class::MODEL == BrainrotType
    render "admin/catalog/index"
  end

  def new
    @record = self.class::MODEL.new
    authorize_admin!(@record, :create)
    render "admin/catalog/form"
  end

  def create
    @record = self.class::MODEL.new(catalog_attributes)
    Admin::Mutation.call(actor: Current.user, record: @record, action: "create") { @record.save! }
    redirect_to catalog_path, notice: "Eintrag erstellt.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    render "admin/catalog/form", status: :unprocessable_entity
  rescue ActiveRecord::RecordNotUnique
    @record.errors.add(:base, "Dieser Name ist bereits vergeben.")
    render "admin/catalog/form", status: :unprocessable_entity
  end

  def edit
    authorize_admin!(@record, :update)
    render "admin/catalog/form"
  end

  def update
    Admin::Mutation.call(actor: Current.user, record: @record, action: "update") do
      @record.with_lock { @record.update!(catalog_attributes) }
    end
    notice = if @record.is_a?(BrainrotType) && @record.saved_change_to_active?
      @record.active? ? "Kartentyp aktiviert. Er kann wieder aus Packs gezogen werden." : "Kartentyp deaktiviert. Bereits gezogene Karten bleiben erhalten."
    else
      "Änderungen gespeichert."
    end
    redirect_to catalog_path, notice: notice, status: :see_other
  rescue ActiveRecord::RecordInvalid
    render "admin/catalog/form", status: :unprocessable_entity
  rescue ActiveRecord::RecordNotUnique
    @record.errors.add(:base, "Dieser Name ist bereits vergeben.")
    render "admin/catalog/form", status: :unprocessable_entity
  end

  def destroy
    Admin::Mutation.call(actor: Current.user, record: @record, action: "destroy") do
      @record.with_lock { @record.destroy! }
    end
    redirect_to catalog_path, notice: "Kartentyp gelöscht.", status: :see_other
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::InvalidForeignKey
    redirect_to catalog_path, alert: "Dieser Kartentyp wird bereits verwendet. Deaktiviere ihn stattdessen, damit vorhandene Karten erhalten bleiben.", status: :see_other
  end

  private

  def set_record
    @record = self.class::MODEL.find(params[:id])
  end

  def catalog_attributes
    fields = self.class::FIELDS.dup
    fields << :starter if self.class::MODEL == Pack && action_name == "create"
    params.expect(self.class::MODEL.model_name.param_key.to_sym => fields)
  end

  def catalog_path
    polymorphic_path([ :admin, self.class::MODEL ])
  end

  def catalog_name
    self.class::LABEL
  end
end
