
set proj_dir [get_property DIRECTORY [current_project]]
set proj_name [get_property NAME [current_project]]

foreach {mod} [list on_screen_display floppy_drive acsi_drive atari_ikbd vclkconvert fx68k atarist_bus glue mmu shifter video_mixer mc68901 acia6850 dma_controller wd1772 ym2149 sound_mixer] {
  create_fileset -blockset -define_from $mod $mod
  set ooc_dir "${proj_dir}/${proj_name}.srcs/${mod}/new"
  set ooc_xdc "${mod}_ooc.xdc"
  set filename "${ooc_dir}/${ooc_xdc}"
  file mkdir $ooc_dir
  close [ open $filename w ]
  add_files -fileset $mod $filename
  set data {# Set out-of-context module specific definitions here}
  set fileId [open $filename "w"]
  puts $fileId $data
  close $fileId
  set_property USED_IN {out_of_context synthesis implementation}  [get_files $filename]
}
