object false

node(:timenet) { timetable.timenet_with_states(@date, @nearest_time, partner_phone?) }
node(:message) { timetable.timenet_message(@date) }

node(:ny_offline_day) { timetable.ny_offline_day? }
