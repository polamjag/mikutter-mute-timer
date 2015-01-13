require 'timers'

Plugin.create(:mute_timer) do
  on_boot do |service|
    if UserConfig[:mute_timer_queue].nil?
      # [{deadline: Time, sn: User.idname}, ...]
      UserConfig[:mute_timer_queue] = []
    else
      UserConfig[:mute_timer_queue].each do |i|
        if Time.now < i[:deadline]
          unmute(u)
          atomic {
            q = UserConfig[:mute_timer_queue].melt
            q.delete_if do |i|
              i[:sn] == u
            end
            UserConfig[:mute_timer_queue] = q
          }
        end
      end
    end

    UserConfig[:mute_timer_delay_time] ||= 10
  end

  timers = Timers::Group.new
  Thread.new do
    loop {
      timers.wait
      sleep 3
    }
  end


  # see core/profile.rb
  def mute(user)
    atomic {
      muted = (UserConfig[:muted_users] ||= []).melt
      muted << user
      UserConfig[:muted_users] = muted
    }
  end
  def unmute(user)
    atomic {
      muted = (UserConfig[:muted_users] ||= []).melt
      muted.delete user
      UserConfig[:muted_users] = muted
    }
    p UserConfig[:muted_users]
  end

  command(:mute_timer,
          name: "mute timer",
          condition: lambda {|o| true},
          visible: true,
          role: :timeline
         ) do |tg|
    tg.messages.each do |tw|
      p tw
      sn = tw[:user][:idname]
      delay = UserConfig[:mute_timer_delay_time]
      mute(sn)
      atomic {
        q = UserConfig[:mute_timer_queue].melt
        q << {deadline: Time.now + delay, sn: sn}
        UserConfig[:mute_timer_queue] = q
      }
      timers.after(delay) {
        unmute(sn)
        atomic {
          q = UserConfig[:mute_timer_queue].melt
          q.delete_if do |i|
            i[:sn] == sn
          end
          p q
          UserConfig[:mute_timer_queue] = q
        }
      }
    end
  end

  settings "mute timer" do
    input "delay time (in seconds)", :mute_timer_delay_time
  end
end
