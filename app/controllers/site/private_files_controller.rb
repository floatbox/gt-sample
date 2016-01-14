class Site::PrivateFilesController < ApplicationController

  load_and_authorize_resource

  def show
    file = PrivateFile.find(params[:id])
    send_file file.attachment.path
  end
end
