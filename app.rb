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
  pars = {}
  post '/render/frames' do
    # convert params to an array type thing
    puts params.inspect

    if params[:blend_file] == 'Upload new file'
      pars = params.dup
      @need_file = true
      redirect(url('/upload'))
    end
    r(params[:blend_file], params[:num_cpus], params[:walltime], params[:account], params[:frame_range],
      params[:project_directory])

    redirect(url("/projects/#{File.basename(params[:project_directory])}"))
  end
  # define the render function with argument params
  def r(blend_file, num_cpus, walltime, account, frame_range, project_directory)
    # check if the blend file is "Upload new file"
    # params[]
    # walltime is passed in in hours, we need to convert it to hh:mm:ss format
    walltime = format('%02d:00:00', walltime) # yeah im a gamer
    args = ['-A', account, '-n', num_cpus]
           .concat(['-t', walltime, '-M', 'pitzer'])
           .concat(['--parsable', '--export',
                    "BLEND_FILE_PATH=#{blend_file},OUTPUT_DIR=#{project_directory},FRAME_RANGE=#{frame_range}"])
    script = "#{__dir__}/scripts/render_frames.sh"
    output = `/bin/sbatch #{args.join ' '} #{script} 2>&1`

    session[:flash] = { info: "Submitted job with output #{output} and args #{args.inspect}" }
    puts "Submitted job with output #{output} and args #{args.inspect}"
  end

  get '/upload' do
    erb(:upload)
  end

  post '/upload' do
    # upload a .blend file to the blend_files directory

    puts params.inspect
    unless params[:file] && (tempfile = params[:file][:tempfile]) && (name = params[:file][:filename])
      session[:flash] = { danger: 'no file uploaded' }
      redirect(url('/upload'))
    end
    target = "#{__dir__}/blend_files/#{name}"
    File.open(target, 'wb') { |f| f.write(tempfile.read) }
    session[:flash] = { info: "uploaded #{params[:file][:filename]}" }
    pars.merge!(blend_file: name)
    # redirect to the post
    @need_file = false
    r(pars[:blend_file], pars[:num_cpus], pars[:walltime], pars[:account], pars[:frame_range],
      pars[:project_directory])
    pars = {}
    redirect(url('/'))
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

  post '/render/video' do
    logger.info("Trying to render video with: #{params.inspect}")

    output_dir = params[:project_directory]
    frames_per_second = params[:frames_per_second]
    walltime = format('%02d:00:00', params[:walltime])

    args = ['-J', 'blender-video', '--parsable', '-A', params[:account]]
    args.concat ['--export', "FRAMES_PER_SEC=#{frames_per_second},OUTPUT_DIR=#{output_dir}"]
    args.concat ['-n', params[:num_cpus], '-t', walltime, '-M', 'pitzer']
    args.concat ['--output', "#{output_dir}/video-render-%j.out"]
    output = `/bin/sbatch #{args.join(' ')}  #{__dir__}/scripts/render_video.sh 2>&1`

    job_id = output.strip.split(';').first

    session[:flash] = { info: "Submitted job #{job_id}"}
    redirect(url("/projects/#{output_dir.split('/').last}"))
  end
end
