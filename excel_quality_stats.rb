#!/usr/bin/env ruby

require 'bio'
require 'axlsx'

=begin
I'm annoyed that all of the programs out there to calculate average quality are difficult to use
or don't do what I want.  This is a program to go through and tabulate into a single excel sheet the 
basic quality statistics of all the pacbio projects in pacbio's home.  It doesn't take any arguments
it goes straight to the home folder and attempts to figure out all the quality stats. Be warned, 
running this program will almost certainly take some time as it has to go through every fastq/qual 
file, average the quality of each read, and blah blah.  You know, make stats.
In general I tend to refer to these like this:

ec    Error Corrected Reads
flr   Filtered Long Reads
ccs   Circular Concesus Reads

=end

puts "Stay a while, and listen.  I mean, be prepared to wait, gonna take time son."



#fq = Bio::FlatFile.auto('filtered_subreads.fastq')
#fr = fq.first
#fr.qualities.inject{|sum, e1| sum+e1}.to_f / fr.qualities.size
#fr.qualities.reduce(:+).to_f / fr.qualities.size

@excel_row = 
[
 "bnum",
 ###CCS Reads###
 "ccs_avg_qual", 
 "ccs_tot_reads", 
 "ccs_min_qual", 
 "ccs_max_qual", 
 "ccs_min_read", 
 "ccs_max_read", 
 ###Error Corrected Long Reads###
 "ec_avg_qual",
 "ec_tot_reads", 
 "ec_min_qual", 
 "ec_max_qual", 
 "ec_min_read", 
 "ec_max_read",
 ###Filtered Long Reads###
 "flr_avg_qual",
 "flr_tot_reads", 
 "flr_min_qual", 
 "flr_max_qual", 
 "flr_min_read", 
 "flr_max_read"
]

@row_hash = {}



def get_qual(file)
  totalReads  = 0
  totalQual   = 0
  averageQual = 0
  minQual     = 1000
  maxQual     = 0
  minRead     = 200000
  maxRead     = 0

#First take care of the qual file (error corrected long reads)
  if /\.qual/ =~ file
    ec = Bio::FlatFile.auto(file)
    puts ".qual file success!"

    ec.each do |q|
      fq = q.to_s.split.map(&:to_i)
      currQual = fq.reduce(:+).to_f / fq.size
      totalQual += currQual
      totalReads += 1
      
      minQual = currQual if currQual < minQual
      maxQual = currQual if currQual > maxQual
      
      minRead = fq.size if fq.size < minRead
      maxRead = fq.size if fq.size > maxRead
      
    end

    averageQual = totalQual/totalReads

    @row_hash['ec_avg_qual']  = averageQual
    @row_hash['ec_tot_reads'] = totalReads
    @row_hash['ec_min_qual']  = minQual
    @row_hash['ec_max_qual']  = maxQual
    @row_hash['ec_min_read']  = minRead
    @row_hash['ec_max_read']  = maxRead


#Then the ccs fastq
  elsif /.+ccs\.fastq/ =~ file
    ccs = Bio::FlatFile.auto(file)
    puts "ccs fastq file success!"

    ccs.each do |q|
      fq = q.qualities
      currQual = fq.reduce(:+).to_f / fq.size
      totalQual += currQual
      totalReads += 1
      
      minQual = currQual if currQual < minQual
      maxQual = currQual if currQual > maxQual
      
      minRead = fq.size if fq.size < minRead
      maxRead = fq.size if fq.size > maxRead
      
    end

    averageQual = totalQual/totalReads

    @row_hash['ccs_avg_qual']  = averageQual
    @row_hash['ccs_tot_reads'] = totalReads
    @row_hash['ccs_min_qual']  = minQual
    @row_hash['ccs_max_qual']  = maxQual
    @row_hash['ccs_min_read']  = minRead
    @row_hash['ccs_max_read']  = maxRead

#Lastly the filtered long reads fastq.
  elsif /filtered_subreads\.fastq/ =~ file
    flr = Bio::FlatFile.auto(file)
    puts "filtered long reads a success"
    flr.each do |q|
      fq = q.qualities
      currQual = fq.reduce(:+).to_f / fq.size
      totalQual += currQual
      totalReads += 1
      
      minQual = currQual if currQual < minQual
      maxQual = currQual if currQual > maxQual
      
      minRead = fq.size if fq.size < minRead
      maxRead = fq.size if fq.size > maxRead
      
    end

    averageQual = totalQual/totalReads

    @row_hash['flr_avg_qual']  = averageQual
    @row_hash['flr_tot_reads'] = totalReads
    @row_hash['flr_min_qual']  = minQual
    @row_hash['flr_max_qual']  = maxQual
    @row_hash['flr_min_read']  = minRead
    @row_hash['flr_max_read']  = maxRead

  end
end



@p = Axlsx::Package.new

##Creates a new excel workbook object and returns a worksheet in it
def create_workbook
  @p.use_autowidth = true
  w = @p.workbook
  w.use_autowidth
  ws = ''
  w.styles do |s|
    blue_cell = s.add_style(
      :bg_color => "B0C4DE", 
      :fg_color => "00", :sz => 11, 
      :alignment =>{:horixontal => :center}, 
      :font_name => 'Calibri', 
      :border => Axlsx::STYLE_THIN_BORDER
    )
    #I want to modify the header so it prints better, but I don't want to modify the original array
    wh = @excel_row.map do |e| e.dup end
    w.add_worksheet(:name => "Pacbio Read Stats") do |sheet|
      sheet.add_row wh, :style => blue_cell
      ws = sheet
    end
    
  end
  ws
end


##Takes a hash and a workbook adds a new record to the workbook
def add_new_record(h, ws)
  row_array = []
  @excel_row.each do |a|
    row_array.push(h[a])
  end
  ws.add_row row_array
end

##Save workbook to disk and close workbook
def write_workbook
  s = @p.to_stream()
  puts Dir.pwd
  File.open('pacbio_reads_stats.xlsx', 'w'){|f| f.write(s.read)}
end


############################################################################
#######The main event
###########################################################################

sheet = create_workbook

Dir.chdir('/home/pacbio')
Dir.open(Dir.pwd).each do |d|
  #We are only interested in directories with assemblies which are not hidden
  @row_hash = {}
  if File.directory?(d) && /^\./ !~ d
    Dir.chdir(d)
    assemblies = Dir.glob "*_assembly"

    if assemblies.empty?
      Dir.chdir "/home/pacbio"
      next
    else
      assemblies.each do |a|

        bnum = /(.+)_assembly/.match(a)
        @row_hash['bnum'] = bnum[1]

        #take care of the Error Corrected reads
        ec_file = File.absolute_path(a) + "/../" + bnum[1] + ".qual"
        if File.exists?(ec_file)
          get_qual(ec_file)
        else
          puts ec_file + ' does not exist!'
        end

        #Take care of the ccs reads
        ccs_file = File.absolute_path(a) + "/ccs.fastq"
        if File.exists?(ccs_file)
          get_qual(ccs_file)
        else
          puts ccs_file + ' does not exist!'
        end

        #Take care of the Filtered Long Reads
        flr_file = File.absolute_path(a) + "/filtered_subreads.fastq"
        if File.exists?(flr_file)
          get_qual(flr_file)
        else
          puts flr_file + ' does not exist!'
        end

        #The magic of writing the line to an excel sheet finally happens
        add_new_record(@row_hash, sheet)

      end

      Dir.chdir "/home/pacbio"
      next
    end
  end
end

write_workbook

