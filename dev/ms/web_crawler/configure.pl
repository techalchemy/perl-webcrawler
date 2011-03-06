# Currently just a placeholder. dumping grounds for suspected relevant information

# Getting machine information
#	Sys::Info::Device::CPU
#		bitness
#		count
#		load (1 min)
#		speed (mhz)
#		identity
#		cache
#		cache_timeout
#		hyperthreading
#		num threads if ht is enabled
#	Linux::SysInfo
#		uptime
#		load 1, 5, 15
#		total ram
#		free ram
#		shared ram
#		buffered ram
#		total swap
#		free swap
#		procs
#		mem_unit (size of mem_unit in bytes?)
#
##################################
# Making Directory structure of code unnoticeable by modules and scripts
#	Pseudocode
#		recursively enumerate directories contained in web_crawler directory
#		add all of these to @INC
#