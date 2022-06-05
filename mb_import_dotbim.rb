require 'sketchup.rb'
require 'extensions.rb'

module MattiaBressanelli
  module ImportDotBim

    unless file_loaded?(__FILE__)
    
      ex = SketchupExtension.new('Import .bim', 'mb_import_dotbim/main')

      ex.description = 'Importer (Ruby based) for the .bim file format.'
      ex.version     = '1.0.0'
      ex.creator     = 'Mattia Bressanelli'

      Sketchup.register_extension(ex, true)

      file_loaded(__FILE__)
    end

  end # module ImportDotBim
end # module MattiaBressanelli