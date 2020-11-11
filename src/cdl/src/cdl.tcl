namespace eval cdl {
  variable cdl_masters {}
  variable unconnected_idx 0

  proc set_message {level message} {
    return "\[$level\] $message"
  }

  proc debug {message} {
    set state [info frame -1]
    set str ""
    if {[dict exists $state file]} {
      set str "$str[dict get $state file]:"
    }
    if {[dict exists $state proc]} {
      set str "$str[dict get $state proc]:"
    }
    if {[dict exists $state line]} {
      set str "$str[dict get $state line]"
    }
    puts [set_message DEBUG "$str: $message"]
  }
  
  proc information {id message} {
    puts [set_message INFO [format "\[CDLN-%04d\] %s" $id $message]]
  }

  proc warning {id message} {
    puts [set_message WARN [format "\[CDLN-%04d\] %s" $id $message]]
  }

  proc err {id message} {
    puts [set_message ERROR [format "\[CDLN-%04d\] %s" $id $message]]
  }

  proc critical {id message} {
    error [set_message CRIT [format "\[CDLN-%04d\] %s" $id $message]]
  }

  proc clear {} {
    variable cdl_masters

    set cdl_masters {}
    set unconnected_idx 0
  }

  proc process_subckt_header {line} {
    variable cdl_masters

    set cell_name [lindex $line 1]
    dict set cdl_masters $cell_name pins [lrange $line 2 end]
  }

  proc get_subckt_header {cell_name} {
    variable cdl_masters

    if {![dict exists $cdl_masters $cell_name pins]} {
      err 2 "Cannot find CDL header for $cell_name"
    }

    return [dict get $cdl_masters $cell_name pins]
  }

  proc read_master {file_name} {
    if {[catch {set ch [open $file_name]} msg]} {
      err 3 $msg
    }

    set line [gets $ch]
    while {![eof $ch]} {
      if {[regexp {^\s*\.[Ss][Uu][Bb][Cc][Kk][Tt]\s} $line]} {
        while {![eof $ch]} {
          set next_line [gets $ch]
          if {[regexp {^\+(.*)$} $next_line - extra]} {
            set line "$line $extra"
          } else {
            process_subckt_header $line
            set line $next_line
            break
          }
        }
      } else {
        set line [gets $ch]
      }
    }
  }

  proc read_masters {file_names} {
    foreach file_name $file_names {
      read_master $file_name
    }
  }

  proc unconnected_net_name {} {
    variable block
    variable unconnected_idx

    while {[$block findNet "_unconnected_$unconnected_idx"] != "NULL"} {
      incr unconnected_idx
    }
    set name  "_unconnected_$unconnected_idx"
    incr unconnected_idx
    return $name
  }

  proc get_net_name_connected_to_pin {inst pin_name} {
    variable block

    set iTerm [$inst findITerm $pin_name]
    if {$iTerm == "NULL"} {
      return [unconnected_net_name]
    }

    set net [$iTerm getNet] 
    if {$net == "NULL"} {
      return [unconnected_net_name]
    }

    return [$net getName]
  }

  proc write_cdl_line {line} {
    variable cdl_file

    set cdl_line ""
    foreach item $line {
      if {[string length $cdl_line] <= 1 && [string length $cdl_line] + [string length $item] > 78} {
        lappend cdl_line $item
        puts $cdl_file [join $cdl_line " "]
        set cdl_line "+"
      } elseif {[string length $cdl_line] + [string length $item] > 78} {
        puts $cdl_file [join $cdl_line " "]
        set cdl_line "+ $item"
      } else {
        lappend cdl_line $item
      }
    }
    puts $cdl_file [join $cdl_line " "]
  }

  proc open_cdl_file {file_name} {
    variable cdl_file

    if {[catch {set cdl_file [open $file_name "w"]} msg]} {
      err 1 $msg
    }
  }

  proc close_cdl_file {} {
    variable cdl_file

    close $cdl_file
  }

  proc out {file_name} {
    variable block

    set block [ord::get_db_block]

    open_cdl_file $file_name
    write_cdl_line "$ CDL Netlist generated by OpenROAD [ord::openroad_version]"
    write_cdl_line ""
    write_cdl_line "*.BUSDELIMITER \["
    write_cdl_line ""

    set line ".SUBCKT [$block getName]"
    foreach pin [$block getBTerms] {
      set line "$line [$pin getName]"
    }
    write_cdl_line $line

    foreach inst [$block getInsts] {
      set master [$inst getMaster]
      if {[$master isFiller]} {continue}
      set cell_name [$master getName] 
      set line "X[$inst getName]"
      
      foreach pin_name [get_subckt_header $cell_name] {
        set line "$line [get_net_name_connected_to_pin $inst $pin_name]"
      }
      write_cdl_line "$line $cell_name"
    }
    write_cdl_line ".ENDS [$block getName]"

    close_cdl_file
  }

  namespace export out clear read_masters
  namespace ensemble create
}
