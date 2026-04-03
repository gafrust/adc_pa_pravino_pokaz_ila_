# ============================================================================
# Создание пользовательского IP из adc_pa.v и RES.v (без generate_xgui_files)
# ============================================================================

catch { close_project }
create_project -force temp_ip_project ./temp_ip_project -part xc7k420tiffg901-2L

if {[get_files adc_pa.v -quiet] == ""} { add_files -norecurse adc_pa.v }
if {[get_files RES.v -quiet] == ""}   { add_files -norecurse RES.v }

set_property top adc_pa [current_fileset]
update_compile_order -fileset sources_1

if {![file exists "./temp_ip_project/temp_ip_project.runs/synth_1/adc_pa.dcp"]} {
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
}
open_run synth_1 -name synth_1

ipx::package_project -root_dir ./my_adc_ip -vendor your_company.com -library user -taxonomy /UserIP -import_files -set_current true -force

set_property display_name "ADC Interface PA" [ipx::current_core]
set_property description "ADC interface module with SPI and data capture" [ipx::current_core]
set_property vendor_display_name "Radiocomp" [ipx::current_core]
set_property company_url "https://www.radiocomp.ru" [ipx::current_core]

ipx::save_core [ipx::current_core]
ipx::update_source_project_archive -component [ipx::current_core]

puts "✅ IP-ядро успешно создано в папке ./my_adc_ip"
puts "Добавьте путь ./my_adc_ip в IP-репозиторий Vivado."

close_project
