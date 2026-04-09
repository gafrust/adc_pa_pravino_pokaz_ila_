# run.do
# Создаём рабочую библиотеку work
#vlib work

# Компилируем нетлист и тестбенч (указываем правильные пути)
#vlog -work work ../sources_1/new/top_netlist.v ../sources_1/new/tb_adc_pa.v

# Запускаем симуляцию с подключением скомпилированных библиотек
#vsim -L unisims_ver -L secureip -L xpm -voptargs=+acc work.tb_adc_pa

# Добавляем сигналы в окно волн
#add wave -position end sim:/tb_adc_pa/dut/*
#add wave -position end sim:/tb_adc_pa/*

# Запускаем симуляцию на 500 микросекунд
#run 500us

# Можно также выполнить run -all для бесконечного прогона






# run.do
vlib work
vlog -work work ../adc_pa.srcs/sources_1/new/top_netlist.v ../adc_pa.srcs/sources_1/new/tb_adc_pa.v
vsim -L unisims_ver -L secureip -L xpm -voptargs=+acc work.tb_adc_pa
add wave -position end sim:/tb_adc_pa/dut/*
add wave -position end sim:/tb_adc_pa/*
run 500us
