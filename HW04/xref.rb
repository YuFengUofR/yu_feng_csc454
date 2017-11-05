#!/usr/bin/env ruby

class CodeLine 
    attr_accessor :address, :line, :jmp_addr, :func
    def initialize(addr, l, ad = nil, f = nil)
        self.address = addr
        self.line = l
        self.jmp_addr = ad
        self.func = f
    end
end


class FuncAssembly 
    @name
    @first_line
    attr_accessor :assembly, :first_addr
    @subroutine
    def initialize(name, line)
        @name = name
        @assembly = Array.new
        @first_line = line;
        @first_addr = line.split(' ')[0][10..16]
        @subroutine = [];
    end
    def add_subroutine(addr, func=nil) 
        @subroutine << [addr, func]
    end
    def show_name
        puts @name
    end
    def show_subroutine
        puts @subroutine
    end
    def show_lines
        @assembly.each { |code|
            print code.line
        }
    end
    def show_addrs
        @assembly.each { |code|
            puts code.address
        }
    end
end


######################################################################

objdump_output = []
obj_r, obj_io = IO.pipe
fork do
  system("objdump -d n_primes", out: obj_io, err: :out)
end
obj_io.close


objdump_head_match = /[0-9a-f]{16}.*\<(\p{Alnum}+?[\p{Alnum}_-]+)\>\:/
objdump_empty_line = /^[[:space:]]*$/
# 
objdump_func_call  = /[\s]+([0-9a-f]{6})\:[\s]+([0-9a-f]{2}\s){5}(\s|callq)*([0-9a-f]{6}).*\<(\p{Alnum}+?[\p{Alnum}_]+)\>.*/
objdump_loc_jump = /[\s]+([0-9a-f]{6})\:[\s]+([0-9a-f]{2}\s){2,}[\s]*j[a-z]*\s*([0-9a-f]{6}).*\<(\p{Alnum}+?\S+)\>.*\n/
objdump_asse_code  = /[\s]+([0-9a-f]{6})\:[\s]+([0-9a-f]{2}\s)+.*/
objdump_dummy_head = /[0-9a-f]{16}.*\<frame_dummy\>:/

curr = nil
ifAdd = false

obj_r.each_line { |l| 
    if objdump_head_match.match(l) then
        curr =  FuncAssembly.new(Regexp.last_match(1), l)
        objdump_output << curr;
        ifAdd = true;
    elsif objdump_empty_line.match(l) then
        ifAdd = false
    else
        if ifAdd && objdump_func_call.match(l) then
            curr.assembly << CodeLine.new(Regexp.last_match(1), 
                    l, Regexp.last_match(4), Regexp.last_match(5))
            curr.add_subroutine(Regexp.last_match(4), Regexp.last_match(5))
        elsif ifAdd && objdump_loc_jump.match(l) && ifAdd then 
            curr.assembly << CodeLine.new(Regexp.last_match(1), 
                                    l, Regexp.last_match(3))
            curr.add_subroutine(Regexp.last_match(3))
        elsif ifAdd && objdump_asse_code.match(l) then
            curr.assembly << CodeLine.new(Regexp.last_match(1), l)
        end
    end
    objdump_output.clear() if objdump_dummy_head.match(l)

}


total_assembly = {}
objdump_output.each { |e|
    e.show_name
    e.first_addr
    e.show_subroutine
    e.show_lines
    total_assembly[e.first_addr] = {}
    e.assembly.each { |l|
        total_assembly[e.first_addr][l.address] = [l.line, l.jmp_addr, l.func]
    }
}

# objdump_output.each { |e|
#     e.show_name
#     e.show_addrs
# }

total_assembly.each { |e|
    e.each { |l|
        p l
    }
}



######################################################################

class CodeMap
    attr_accessor :source_map, :path, :lines, :codes, :assembly_map, :min
    @max
    def initialize(path, addr, lno, col, sig)
        @min = lno
        @max = lno
        @path = path
        @lines = {}
        @lines[lno] = []
        @lines[lno] << addr
        @source_map = {}
        @source_map[addr] = [lno, col, sig]
    end
    def add_addr(lno, addr)
        if @lines[lno].nil? then 
            @lines[lno] = []
        end
        @lines[lno] << addr 
        @max = @max > lno ? @max : lno
    end
    def construct
        total = File.readlines(@path).size
        tmp = {}
        prev = ''
        (@min..total).each { |i|
            if i < @min then
                tmp[i] = @lines[@min]
            elsif i > @max then
                tmp[i] = @lines[@max]
            else
                if !lines[i].nil? then
                    tmp[i] = lines[i]
                    prev = lines[i]
                else 
                    tmp[i] = prev
                end
            end
        }
        @lines = tmp
    end
    def read_file
        @codes = [""]
        File.open(@path).each { |l|
            @codes << l
        }
    end
    def match_assembly
        @assembly_map = {}
        lines.each { |k,v|
            v.each { |a|
                if @assembly_map[a].nil? then
                    @assembly_map[a] = [k]
                else 
                    @assembly_map[a] << k
                end
            }
            
        }
    end
    def add_func(total_assembly)
        addrs = [];
        assembly_map.each_key { |addr|
            if !total_assembly[addr].nil? then
                addrs << addr
            end
        }
        addrs.each { |addr|
            total_assembly[addr].each { |k, v|
                if assembly_map[k].nil? then
                    assembly_map[k] = [v]
                else
                    assembly_map[k] << v 
                end
            }
        }
    end
end

######################################################################

dwarf_output = []
dwarf_r, dwarf_io = IO.pipe
fork do
  res = system("~cs254/bin/dwarfdump -l n_primes", out: dwarf_io, err: :out)
end

dwarf_io.close

debug_matcher = /^0x00([0-9a-f]{6})\s+\[\s+([0-9]+)\,\s+([0-9]+)\]\s+([A-Z]+.*)$/
uri_matcher = /^(.*)uri\:[\s]+\"(.+)\".*$/

curr = nil

dwarf_r.each { |l|
    puts l
    if debug_matcher.match(l) then
        addr = Regexp.last_match(1)
        lno = Regexp.last_match(2).to_i
        col = Regexp.last_match(3).to_i
        info = Regexp.last_match(4)
        if (uri_matcher.match(info)) then
            sig = Regexp.last_match(1).strip().split(' ')
            path = Regexp.last_match(2)
            curr = CodeMap.new(path, addr, lno, col, sig)
            dwarf_output << curr
        else 
            sig = info.strip().split(' ')
            curr.add_addr(lno, addr)
            curr.source_map[addr] = [lno, col, sig]
        end
    end
}


dwarf_output.each { |e|
    e.construct
    e.read_file
    puts e.lines
    puts e.codes
}

dwarf_output.each { |e|
    e.match_assembly
    e.add_func(total_assembly)
    e.assembly_map.each { |l|
        p l
    }
}



dwarf_output.each { |e|
    assembly_text = ''
    code_text = ''
    lead_cnt = 1
    asse_cnt = 1
    code_cnt = 1
    lines_set = {}
    while code_cnt < e.min
        code_text += "[#{code_cnt}, X]\t#{e.codes[code_cnt]}"
        code_cnt += 1
    end
    lead_cnt = lead_cnt < code_cnt ? code_cnt : lead_cnt
    e.assembly_map.keys.sort.each { |addr|
        curr_cnt = lead_cnt
        need_write = true
        e.assembly_map[addr].each { |i|
            if i.class == Integer && need_write then
                while code_cnt < curr_cnt 
                    code_text += "[#{code_cnt}, X]\t\n"
                    code_cnt += 1
                end
                code_text += "[#{code_cnt}, #{i}]\t#{e.codes[i]}"
                need_write = false if lines_set.key?(i)
                lines_set[i] = true
                code_cnt += 1
                lead_cnt = lead_cnt < code_cnt ? code_cnt : lead_cnt
            elsif i.class != Integer then
                while asse_cnt < curr_cnt
                    assembly_text += "[#{asse_cnt}]\t\n"
                    asse_cnt += 1
                end
                assembly_text += "[#{asse_cnt}]\t#{i[0]}"
                asse_cnt += 1
                lead_cnt = lead_cnt < asse_cnt ? asse_cnt : lead_cnt
            end
        }
    }
    print assembly_text
    puts "==================================="
    print code_text
    puts "***********************************"
}



