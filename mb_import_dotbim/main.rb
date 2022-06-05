require 'sketchup.rb'
require 'json'

module MattiaBressanelli
    module ImportDotBim

    # set input file
    @input_file = nil

    # set default parameters
    @get_metadata = true
    @use_colors = true
    @soften_edges = false

    # main function
    def self.main()
        # get import dialog
        dialog = UI::HtmlDialog.new(
            {
            :dialog_title => "Import .bim",
            :scrollable => false,
            :resizable => false,
            :width => 360,
            :height => 680,
            :style => UI::HtmlDialog::STYLE_DIALOG
            }
        )
        dialog.set_file(File.join(File.dirname(__FILE__), "/dialogs/import.html"))
        dialog.center
        dialog.show

        dialog.add_action_callback("select_input_file") { |action_context|
            js_command = "document.getElementById('input-file').value = ''"
            @input_file = UI.openpanel("Select .bim File", "c:/", "BIM|*.bim||")
            if not (@input_file === nil)
                @input_file.gsub!("\\", "/")
                js_command = "document.getElementById('input-file').value = '" + @input_file + "'"
            end
            dialog.execute_script(js_command)
        }

        dialog.add_action_callback("get_parameters") { |action_context, get_metadata, use_colors, soften_edges|
            @get_metadata = get_metadata
            @use_colors = use_colors
            @soften_edges = soften_edges
        }

        dialog.add_action_callback("import_function") { |action_context|
            if not (@input_file === nil)
                self.import

                # at end of operation
                dialog.close
            else
                UI.messagebox("Please specify a valid input file")
            end
        }
    end

    # define a function to import .bim
    def self.import()
        # get active model
        model = Sketchup.active_model

        # start operation (to see the import as one thing in the undo stack)
        model.start_operation('import_dotbim', true)

        # get json file and parse it to a ruby hash
        raw_data = File.read(@input_file)
        datahash = JSON.parse(raw_data)  

        # get the definitions in the model (clear the unused ones)
        definitions = model.definitions
        definitions.purge_unused

        # for each element in the .bim file
        for j in datahash["elements"] do

            # add a new definition
            definition = definitions.add(j["guid"])

            # get the mesh data
            coordinates = datahash["meshes"][j["mesh_id"]]["coordinates"]
            indices = datahash["meshes"][j["mesh_id"]]["indices"]

            # .bim faces are all triangles
            n_faces = indices.length / 3

            # initialize a polygon-mesh
            mesh = Geom::PolygonMesh.new

            # for each face
            for i in 0..(n_faces - 1) do

                # get the points coordinates
                points = [
                [ coordinates[ indices[0+3*i]*3 ].m, coordinates[ indices[0+3*i]*3 + 1].m, coordinates[ indices[0+3*i]*3 + 2].m ],
                [ coordinates[ indices[1+3*i]*3 ].m, coordinates[ indices[1+3*i]*3 + 1].m, coordinates[ indices[1+3*i]*3 + 2].m ],
                [ coordinates[ indices[2+3*i]*3 ].m, coordinates[ indices[2+3*i]*3 + 1].m, coordinates[ indices[2+3*i]*3 + 2].m ]
                ] 

                # add the face to the polygon-mesh
                mesh.add_polygon(points)
            end

            # add the mesh to the definition
            if @soften_edges
                definition.entities.fill_from_mesh(mesh, true, 4)
            else
                definition.entities.fill_from_mesh(mesh, true, 0)
            end

            # get transform data
            v_x = j["vector"]["x"].m
            v_y = j["vector"]["y"].m
            v_z = j["vector"]["z"].m
            q_x = j["rotation"]["qx"]
            q_y = j["rotation"]["qy"]
            q_z = j["rotation"]["qz"]
            q_w = j["rotation"]["qw"]

            array = [1-2*(q_y**2+q_z**2), 2*(q_x*q_y+q_w*q_z), 2*(q_x*q_z-q_w*q_y), 0,
                    2*(q_x*q_y-q_w*q_z), 1-2*(q_x**2+q_z**2), 2*(q_y*q_z+q_w*q_x), 0,
                    2*(q_x*q_z+q_w*q_y), 2*(q_y*q_z-q_w*q_x), 1-2*(q_x**2+q_y**2), 0,
                    v_x, v_y, v_z, 1]       

            transform = Geom::Transformation.new(array)

            # create the instance of each definition with its transform
            instance = model.entities.add_instance(definition, transform)        

            # add colors from rgba string
            if @use_colors
                color_from_rgba = Sketchup::Color.new(j["color"]["r"].round(0), j["color"]["g"].round(0), j["color"]["b"].round(0), j["color"]["a"].round(0))       
                instance.material = color_from_rgba
                instance.material.alpha = j["color"]["a"] / 255.0
            end

            # add object data
            if @get_metadata
                dictionary = instance.attribute_dictionary('dot_bim', true)

                j["info"].each{ |key, value|
                    instance.set_attribute(dictionary.name, key, value)
                }
            end
        end

        # end operation (to see the import as one thing in the undo stack)
        model.commit_operation

        # reset the view so that it fits the newly available objects
        Sketchup.active_model.active_view.zoom_extents
    end


    # Menu
    unless file_loaded?(__FILE__)
        menu = UI.menu('Extensions')
        submenu = menu.add_submenu("Dot bim")
        submenu.add_item('Import bim object') {
            self.main
        }
        file_loaded(__FILE__)
    end

    end # module ImportDotBim
end # module MattiaBressanelli
