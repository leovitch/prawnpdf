require 'test_helper'
require 'test/unit'

class DummyList
    def any?
        nil
    end
end
class DummyUser
    attr_reader :name
    def initialize(name)
        @name = name
    end 
end
class DummyJournal
    # DummyUser instance
    attr_reader :user
    # time
    attr_reader :created_on
    # Array of Strings
    attr_reader :details
    # String
    attr_reader :notes
    # bool
    def notes?
        @notes != nil
    end
    def initialize(user,created_on,details,notes)
        @user = DummyUser.new(user)
        @created_on = Time.utc(2010,"jan",1,20,15,1)
        @details = details
        @notes = notes
    end
end
class DummyJournals
    # List of DummyJournal instances
    def find(*args)
        [ DummyJournal.new('Admin Redmine','09/26/2010 09:02 pm',
        ['- Subject changed from A Brand-new Issue no due date to A Brand-new Issue with a due date','Status changed to In Progress'],
        nil),
        DummyJournal.new('Leo Hourvitz','09/26/2010 09:02 pm',
        ['- Due Date changed to 09/27/2010 09:02 pm','Status changed to In Progress'],
        nil) ]
    end
end
class DummyIssue
    # strings
    attr_reader :project, :tracker, :id, :subject
    attr_reader :status, :priority, :author, :category
    attr_reader :assigned_to,:description
    #dates
    attr_reader :created_on, :updated_on, :due_date
    def initialize()
        @project = 'AMProj'
        @tracker = 'Support'
        @id = 48
        @subject = "A Brand-new issue with a due date"
		@description = "This is a new issue which really hasn't been discussed " +
			"yet, but is very interesting and worthy of many journal entries. "+
			"他のニューズとして、日本の政府はあまり良くないです。一人の意見ではなくて、色々な方が"+
			"まったく同じの意見をもっていると言われました。じゃ、やはり、びっくりの事ではないでしょう。"
        @status = 'New'
        @author = 'Admin Redmine'
        @category = nil
        @assigned_to = nil
        @created_on = Date.new(2010,5,25)
        @updated_on = Date.new(2010,5,28)
        @due_date = Date.new(2010,6,15)
    end
    def custom_field_values
        [ ]
    end
    def changesets
        DummyList.new()
    end
    def attachments
        DummyList.new()
    end
    def journals
        DummyJournals.new()
    end
end

# PrawnPDF with a particular footer format
class RedminePDF < PrawnPDF::RPDF
    attr_accessor :footer_date

    def Footer
        SetFont('', 'I', 8)
        SetY(-15)
        SetX(15)
        Cell(0, 5, @footer_date, 0, 0, 'L')
        SetY(-15)
        SetX(-30)
        Cell(0, 5, PageNo().to_s + '/{nb}', 0, 0, 'C')
    end
end
      
class PrawnpdfTest < Test::Unit::TestCase
	
    def test_issue
        issue = DummyIssue.new
		puts "About to initialize PDF object"
        pdf = RedminePDF.new()
		puts "Initialized PDF object"
		pdf.AddFontFamily('Arial','/Library/Fonts/Arial Unicode.ttf')
		pdf.SetFont('Arial')
        pdf.SetTitle("#{issue.project} - ##{issue.tracker} #{issue.id}")
        pdf.AliasNbPages
        pdf.footer_date = Date.today.to_s
        pdf.AddPage

        pdf.SetFontStyle('B',11)    
        pdf.Cell(190,10, "#{issue.project} - #{issue.tracker} # #{issue.id}: #{issue.subject}")
        pdf.Ln

        y0 = pdf.GetY

        pdf.SetFontStyle('B',9)
        pdf.Cell(35,5, 'Status' + ":","LT")
        pdf.SetFontStyle('',9)
        pdf.Cell(60,5, issue.status.to_s,"RT")
        pdf.SetFontStyle('B',9)
        pdf.Cell(35,5, 'Priority' + ":","LT")
        pdf.SetFontStyle('',9)
        pdf.Cell(60,5, issue.priority.to_s,"RT")        
        pdf.Ln

        pdf.SetFontStyle('B',9)
        pdf.Cell(35,5, 'Author' + ":","L")
        pdf.SetFontStyle('',9)
        pdf.Cell(60,5, issue.author.to_s,"R")
        pdf.SetFontStyle('B',9)
        pdf.Cell(35,5, 'Category' + ":","L")
        pdf.SetFontStyle('',9)
        pdf.Cell(60,5, issue.category.to_s,"R")
        pdf.Ln   

        pdf.SetFontStyle('B',9)
        pdf.Cell(35,5, 'Created on:' + ":","L")
        pdf.SetFontStyle('',9)
        pdf.Cell(60,5, issue.created_on.to_s,"R")
        pdf.SetFontStyle('B',9)
        pdf.Cell(35,5, 'Assigned to' + ":","L")
        pdf.SetFontStyle('',9)
        pdf.Cell(60,5, issue.assigned_to.to_s,"R")
        pdf.Ln

        pdf.SetFontStyle('B',9)
        pdf.Cell(35,5, 'Updated on' + ":","LB")
        pdf.SetFontStyle('',9)
        pdf.Cell(60,5, issue.updated_on.to_s,"RB")
        pdf.SetFontStyle('B',9)
        pdf.Cell(35,5, 'Due date' + ":","LB")
        pdf.SetFontStyle('',9)
        pdf.Cell(60,5, issue.due_date.to_s,"RB")
        pdf.Ln

        for custom_value in issue.custom_field_values
            pdf.SetFontStyle('B',9)
            pdf.Cell(35,5, custom_value.custom_field.name + ":","L")
            pdf.SetFontStyle('',9)
            pdf.MultiCell(155,5, (show_value custom_value),"R")
        end

        pdf.SetFontStyle('B',9)
        pdf.Cell(35,5, 'Subject' + ":","LTB")
        pdf.SetFontStyle('',9)
        pdf.Cell(155,5, issue.subject,"RTB")
        pdf.Ln    

        pdf.SetFontStyle('B',9)
        pdf.Cell(35,5, 'Description' + ":")
        pdf.SetFontStyle('',9)
        pdf.MultiCell(155,5, issue.description,"BR")

		pdf.Line(pdf.GetX, y0, pdf.GetX, pdf.GetY)
        pdf.Line(pdf.GetX, pdf.GetY, 170, pdf.GetY)
        pdf.Ln

        if issue.changesets.any? && User.current.allowed_to?(:view_changesets, issue.project)
            pdf.SetFontStyle('B',9)
            pdf.Cell(190,5, 'Associated revisions', "B")
            pdf.Ln
            for changeset in issue.changesets
                pdf.SetFontStyle('B',8)
                pdf.Cell(190,5, changeset.committed_on.to_s + " - " + changeset.author.to_s)
                pdf.Ln
                unless changeset.comments.blank?
                    pdf.SetFontStyle('',8)
                    pdf.MultiCell(190,5, changeset.comments)
                end   
                pdf.Ln
            end
        end

        pdf.SetFontStyle('B',9)
        pdf.Cell(190,5, 'History', "B")
        pdf.Ln
        for journal in issue.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
            pdf.SetFontStyle('B',8)
            pdf.Cell(190,5, journal.created_on.to_s + " - " + journal.user.name)
            pdf.Ln
            pdf.SetFontStyle('I',8)
            for detail in journal.details
                pdf.Cell(190,5, "- " + detail)
                pdf.Ln
            end
            if journal.notes?
                pdf.SetFontStyle('',8)
                pdf.MultiCell(190,5, journal.notes)
            end   
            pdf.Ln
        end

        if issue.attachments.any?
            pdf.SetFontStyle('B',9)
            pdf.Cell(190,5, 'Attachments', "B")
            pdf.Ln
            for attachment in issue.attachments
                pdf.SetFontStyle('',8)
                pdf.Cell(80,5, attachment.filename)
                pdf.Cell(20,5, number_to_human_size(attachment.filesize),0,0,"R")
                pdf.Cell(25,5, attachment.created_on.to_s,0,0,"R")
                pdf.Cell(65,5, attachment.author.name,0,0,"R")
                pdf.Ln
            end
        end
        pdf.Output(File.join(File.dirname(__FILE__),"test_output","TestIssue.pdf"))
    end
end
