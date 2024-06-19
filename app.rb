# frozen_string_literal: true

require 'sinatra/base'
require 'logger'

# App is the main application where all your logic & routing will go
class App < Sinatra::Base
  set :erb, escape_html: true
  enable :sessions

  attr_reader :logger

  def initialize
    super
    @logger = Logger.new('log/app.log')
  end

  def title
    'Summer Instititue Starter App'
  end

  def accounts
    Process.groups.map do |group_id|
      Etc.getgrgid(group_id).name
    end.select do |group|
      group.start_with?('P')
    end
  end

  post '/render/frames' do
    # params[]
    # walltime is passed in in hours, we need to convert it to hh:mm:ss format
    walltime = format('%02d:00:00', params[:walltime]) # yeah im a gamer
    args = ['-A', params[:account], '-n', params[:num_cpus]]
           .concat(['-t', walltime, '-M', 'pitzer'])
           .concat(['--parsable', '--export',
                    "BLEND_FILE_PATH=#{params[:blend_file]},OUTPUT_DIR=#{params[:project_directory]},FRAME_RANGE=#{params[:frame_range]}"])
    script = "#{__dir__}/scripts/render_frames.sh"
    output = `/bin/sbatch #{args.join ' '} #{script} 2>&1`

    session[:flash] = { info: "Submitted job with output #{output} and args #{args.inspect}" }

    redirect(url("/projects/#{File.basename(params[:project_directory])}"))
  end

  get '/upload' do
    erb(:upload)
  end

  post '/upload' do
    # upload a .blend file to the blend_files directory
    if params[:blend_file]
      FileUtils.mv(params[:blend_file][:tempfile].path, "#{__dir__}/blend_files/#{params[:blend_file][:filename]}")
      session[:flash] = { info: "uploaded #{params[:blend_file][:filename]}" }
    else
      session[:flash] = { danger: 'no file uploaded' }
    end
  end

  def project_dirs
    Dir.children(projects_root).select do |path|
      Pathname.new("#{projects_root}/#{path}").directory?
    end.sort_by(&:to_s)
  end

  def blend_files
    Dir.glob("#{__dir__}/blend_files/*.blend")
  end

  def images(project_name)
    Dir.glob("#{project_name}/*.png")
  end

  get '/' do
    logger.info('requsting the index')
    @flash = session.delete(:flash) || { info: 'Welcome to Summer Institute!' }
    erb(:index)
  end

  get '/projects/:name' do
    if params[:name] == 'new'
      erb(:new_project)
    else
      @directory = Pathname.new("#{projects_root}/#{params[:name]}")
      @flash = session.delete(:flash)
      @images = images(@directory)

      if @directory.directory? && @directory.readable?
        erb(:show_project)
      else
        session[:flash] = { danger: "#{params[:name]} does not exist. Maybe try recreating it?" }
        redirect(url('/'))
      end

    end
  end

  # helper function for the parent directory of all projects.
  def projects_root
    "#{__dir__}/projects"
  end

  post '/projects/new' do
    dir = params[:name].downcase.gsub(' ', '_')

    "#{projects_root}/#{dir}".tap { |d| FileUtils.mkdir_p(d) }

    session[:flash] = { info: "made new project '#{params[:name]}'" }
    redirect(url("/projects/#{dir}"))
  end
end
