class SubjectsController < ApplicationController
  before_action :authenticate_user!

  def assign
    processed_params = Hash.new
    %w[gender class_year profession major ethnicity].each do |f|
      processed_params[f] = search_params[f]
    end
    %w[birth_year year_started years_resident current_gpa attendance].each do |f|
      processed_params[f] = ((search_params["#{f}_from"].to_s == '' ? view_context.custom_range[f].min : search_params["#{f}_from"].to_i)..
          (search_params["#{f}_to"].to_s == '' ? view_context.custom_range[f].max : search_params["#{f}_to"].to_i))
    end
    attendance = processed_params["attendance"]
    processed_params.delete "attendance"
    @subjects = Subject.find_by_sql ['
      SELECT u.*, COALESCE(r1.registrations_count, 0) registration_count, COALESCE(r2.shown_up_count,0) shown_up_count
      FROM users u
      LEFT OUTER JOIN (select subject_id, count(*) as registrations_count from registrations group by subject_id) r1 on (r1.subject_id = u.id)
      LEFT OUTER JOIN (select subject_id, count(*) as shown_up_count from registrations where registrations.participated = true group by subject_id) r2 on (r2.subject_id = u.id)
      WHERE u.id in (?) and COALESCE((r2.shown_up_count / r1.registrations_count),100) between ? and ? and (? or r1.registrations_count > 0)',
                                     Profile.where(processed_params).pluck(:user_id),
                                     attendance.min,
                                     attendance.max,
                                     search_params[:never_been].nil?]
    if @subjects.count >= search_params[:required_subjects].to_i
      Experiment.find(search_params[:experiment_id]).subjects << @subjects
      respond_to do |format|
        format.js {
          render 'assigned'
        }
      end
    else
      respond_to do |format|
        format.js {
          render 'fault'
        }
      end
    end
  end
  private
  def search_params
    params.permit(
      :birth_year_from,
      :birth_year_to,
      :year_started_from,
      :year_started_to,
      :years_resident_from,
      :years_resident_to,
      :current_gpa_from,
      :current_gpa_to,
      :attendance_from,
      :attendance_to,
      :never_been,
      :required_subjects,
      :experiment_id,
      {:gender => []},
      {:class_year => []},
      {:profession => []},
      {:major => []},
      {:ethnicity => []}
    )
  end
end