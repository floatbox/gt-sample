object false

if @pc.error_message.present?
  node(:error){ { message: @pc.error_message } }
else
  node(:success){ true }
end
