require 'json'

HOMEBREW_PREFIX = "/"

def cask(name, &block)
    # You can execute the block if provided
    # Create a context for the DSL
    context = CaskContext.new
    # 
    context.instance_eval(&block)  # Evaluate the block in the context of the CaskContext

    context.print();
end

class CaskContext
  attr_accessor :version, :sha256, :url, :name, :desc, :homepage
  def initialize
    @version = nil
    @sha256 = nil
    @url = nil
    @name = []
    @desc = nil
    @homepage = nil
  end

  def version(version_string = nil)
    if (version_string) 
        @version = version_string
    end
    
    return @version
  end

  def method_missing(method_name, *args)
    
    # Here you can define behavior for undefined methods
  end
  def respond_to_missing?(method_name, include_private = false)
    true  # This allows the object to respond to any method, including undefined ones
  end

  def sha256(checksum)
    @sha256 = checksum
  end

  def url(download_url)
    @url = download_url
  end

  def name(cask_name)
    @name.append(cask_name)
  end

  def desc(description)
    @desc = description
  end

  def app(app)
    @app = app
  end

  def homepage(homepage_url)
    @homepage = homepage_url
  end

  def print()
    data = {
        name: @name,
        desc: @desc,
        homepage: @homepage,
        url: @url,
        version: @version,
        sha256: @sha256,
        artifacts: [
            {
                app: [
                    @app
                ]
            }
        ]
    }
    puts JSON.pretty_generate(data)
  end
end

load (File.expand_path ARGV[0])