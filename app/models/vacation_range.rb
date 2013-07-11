class VacationRange < ActiveRecord::Base
  unloadable

  belongs_to :user
  belongs_to :vacation_status

  after_create :change_vacation
  after_save :change_vacation
  after_save :send_notifications

  validates_presence_of :user_id, :start_date, :vacation_status_id
  validates_uniqueness_of :start_date, :scope => :user_id, :on => :create
  validates_uniqueness_of :end_date, :scope => :user_id, :on => :create, :if => Proc.new{ end_date.present? }
  validates_numericality_of :duration, only_integer: true, allow_nil: true
  validate :dates_in_row

  def title_description
    if description.present?
      description.gsub(/\r\n/,"\r")
    end
  end

  if Rails::VERSION::MAJOR >= 3
    scope :limit, lambda {|limit|
      where(:limit => limit)
    }

    scope :order_by_start_date, lambda {|q|
      if q.present?
        where(:order => "start_date #{q}")
      else
        where(:order => "start_date")
      end
    }

    scope :for_user, lambda { |user|
      if user.present?
        where("user_id = :user_id", {:user_id => user})
      end
    }

    scope :like_username, lambda {|q|
      if q.present?
        {:conditions =>
          ["LOWER(users.firstname) LIKE :p OR users.firstname LIKE :p OR LOWER(users.lastname) LIKE :p OR users.lastname LIKE :p",
          {:p => "%#{q.to_s.downcase}%"}],
         :include => :user}
      end
    }

    scope :for_vacation_status, lambda { |status|
      if status.present?
        where("vacation_status_id = :status_id", {:status_id => status})
      end
    }

    scope :planned_vacations, lambda {
      {:conditions =>
        ["vacation_statuses.is_planned = :status",
        {:status => true}],
      :joins => :vacation_status}
    }

    scope :not_planned_vacations, lambda {
      {:conditions =>
        ["vacation_statuses.is_planned = :status",
        {:status => false}],
      :joins => :vacation_status}
    }

    scope :time_period, lambda {|q, field|
      today = Date.today
      if q.present? && field.present?
        {:conditions =>
          (case q
            when "yesterday"
              ["#{field} BETWEEN ? AND ?",
                2.days.ago,
                1.day.ago]
            when "today"
              ["#{field} BETWEEN ? AND ?",
                1.day.ago,
                1.day.from_now]
            when "tomorrow"
              ["#{field} BETWEEN ? AND ?",
                1.day.from_now,
                2.days.from_now]
            when "prev_week"
              ["#{field} BETWEEN ? AND ?",
                2.week.ago + today.wday.days,
                1.week.ago + today.wday.days]
            when "this_week"
              ["#{field} BETWEEN ? AND ?",
                1.week.ago + today.wday.days,
                1.week.from_now - today.wday.days]
            when "next_week"
              ["#{field} BETWEEN ? AND ?",
                1.week.from_now - today.wday.days,
                2.week.from_now - today.wday.days]
            when "prev_month"
              ["#{field} BETWEEN ? AND ?",
                2.month.ago + today.day.days,
                1.month.ago + today.day.days]
            when "this_month"
              ["#{field} BETWEEN ? AND ?",
                1.month.ago + today.day.days,
                1.month.from_now - today.day.days]
            when "next_month"
              ["#{field} BETWEEN ? AND ?",
                1.month.from_now - today.day.days,
                2.month.from_now - today.day.days]
            when "prev_year"
              ["#{field} BETWEEN ? AND ?",
                2.year.ago + today.yday.days,
                1.year.ago + today.yday.days]
            when "this_year"
              ["#{field} BETWEEN ? AND ?",
                1.year.from_now - today.yday.days,
                1.year.from_now - today.yday.days]
            when "next_year"
              ["#{field} BETWEEN ? AND ?",
                1.year.from_now - today.yday.days,
                2.year.from_now - today.yday.days]
            else
              {}
          end)
        }
      end
    }
  else
    named_scope :limit, lambda {|limit|
        {:limit => limit}
    }

    named_scope :order_by_start_date, lambda {|q|
      if q.present?
        {:order => "start_date #{q}"}
      else
        {:order => "start_date"}
      end
    }

    named_scope :for_user, lambda { |user|
      if user.present?
        {:conditions =>
          ["user_id = :user_id", {:user_id => user}]}
      end
    }

    named_scope :like_username, lambda {|q|
      if q.present?
        {:conditions =>
          ["LOWER(users.firstname) LIKE :p OR users.firstname LIKE :p OR LOWER(users.lastname) LIKE :p OR users.lastname LIKE :p",
          {:p => "%#{q.to_s.downcase}%"}],
         :include => :user}
      end
    }

    named_scope :for_vacation_status, lambda { |status|
      if status.present?
        {:conditions =>
          ["vacation_status_id = :status_id", {:status_id => status}]}
      end
    }

    named_scope :planned_vacations, lambda {
      {:conditions =>
        ["vacation_statuses.is_planned = :status",
        {:status => true}],
      :joins => :vacation_status}
    }

    named_scope :not_planned_vacations, lambda {
      {:conditions =>
        ["vacation_statuses.is_planned = :status",
        {:status => false}],
      :joins => :vacation_status}
    }

    named_scope :time_period, lambda {|q, field|
      today = Date.today
      if q.present? && field.present?
        {:conditions =>
          (case q
            when "yesterday"
              ["#{field} BETWEEN ? AND ?",
                2.days.ago,
                1.day.ago]
            when "today"
              ["#{field} BETWEEN ? AND ?",
                1.day.ago,
                1.day.from_now]
            when "tomorrow"
              ["#{field} BETWEEN ? AND ?",
                1.day.from_now,
                2.days.from_now]
            when "prev_week"
              ["#{field} BETWEEN ? AND ?",
                2.week.ago + today.wday.days,
                1.week.ago + today.wday.days]
            when "this_week"
              ["#{field} BETWEEN ? AND ?",
                1.week.ago + today.wday.days,
                1.week.from_now - today.wday.days]
            when "next_week"
              ["#{field} BETWEEN ? AND ?",
                1.week.from_now - today.wday.days,
                2.week.from_now - today.wday.days]
            when "prev_month"
              ["#{field} BETWEEN ? AND ?",
                2.month.ago + today.day.days,
                1.month.ago + today.day.days]
            when "this_month"
              ["#{field} BETWEEN ? AND ?",
                1.month.ago + today.day.days,
                1.month.from_now - today.day.days]
            when "next_month"
              ["#{field} BETWEEN ? AND ?",
                1.month.from_now - today.day.days,
                2.month.from_now - today.day.days]
            when "prev_year"
              ["#{field} BETWEEN ? AND ?",
                2.year.ago + today.yday.days,
                1.year.ago + today.yday.days]
            when "this_year"
              ["#{field} BETWEEN ? AND ?",
                1.year.from_now - today.yday.days,
                1.year.from_now - today.yday.days]
            when "next_year"
              ["#{field} BETWEEN ? AND ?",
                1.year.from_now - today.yday.days,
                2.year.from_now - today.yday.days]
            else
              {}
          end)
        }
      end
    }
  end

  def to_s
    str = format_date(start_date)
    if end_date.present?
      str + ' - ' + format_date(end_date)
    else
      str
    end
  end

  def dates_in_row
    if self.end_date.present? and self.start_date > self.end_date
      errors.add :end_date, :invalid
    end
  end

  def include?(date)
    self.start_date.present? && self.end_date.present? && (self.start_date <= date) && (self.end_date >= date)
  end

  def in_range?(start, ending)
    ending ||= start
    self.include?(start) || self.include?(ending)
      #|| (start <= self.start_date && ending >= self.end_date)
  end


  def change_vacation
    vacation = Vacation.find_by_user_id(user_id) || Vacation.create(:user_id => user_id)

    active_planned, last_planned = *VacationRange.
      planned_vacations.
      for_user(user_id).
      limit(2).
      all(:order => "start_date DESC, end_date DESC")

    not_planned = VacationRange.
      not_planned_vacations.
      for_user(user_id).
      first(:order => "start_date DESC, end_date DESC")

    vacation.update_attributes(
      :last_planned_vacation => last_planned,
      :active_planned_vacation => active_planned,
      :not_planned_vacation => not_planned
    )
  end

  def send_notifications
    issues_author = Issue.with_author(self.user_id).open.
      on_vacation(self).inject({}){ |result,issue|
        if issue.assigned_to.present?
          result.update(issue.assigned_to_id => [issue.id]){|k,o,n| o+n }\
        else
          result
        end
      }
    issues_assigned_to = Issue.with_assigned_to(self.user_id).open.
      on_vacation(self).inject({}){ |result,issue|
        if issue.author.present?
          result.update(issue.author_id => [issue.id]){|k,o,n| o+n }
        else
          result
        end
      }

    ActiveRecord::Base.transaction do
      issues_author.each{ |assigned_to, issues|
        VacationMailer.deliver_from_author(assigned_to, issues, self.id, self.user_id)
      }
      issues_assigned_to.each{ |author, issues|
        VacationMailer.deliver_from_assigned_to(author, issues, self.id, self.user_id)
      }
    end
  end
end
