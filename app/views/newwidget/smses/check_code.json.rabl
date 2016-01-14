object false

if @error.present?
  node(:error){ { message: @error } }
else
  node(:success){ true }

  node(:b_day){ Russian::strftime(@booking.time,'%A, %e %b') }


  node(:b_time) { Russian::strftime(@booking.time,'%H:%M') }
  node(:persons_str) do
    persons = ::Russian.p(@booking.persons, "человек", "человека", "человек")
    "#{@booking.persons} #{persons}"
  end

  node(:persons_count_category) { @booking.persons_count_category }

  node(:phone) { @booking.phone }
end
