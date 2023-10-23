`timescale 1ns / 1ps


module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    output  wire                     awready,
    output  wire                     wready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
    output  wire                     arready,
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata,
    input   wire                     ss_tvalid,
    input   wire [(pDATA_WIDTH-1):0] ss_tdata,
    input   wire                     ss_tlast,
    output  wire                     ss_tready,
    input   wire                     sm_tready,
    output  wire                     sm_tvalid,
    output  wire [(pDATA_WIDTH-1):0] sm_tdata,
    output  wire                     sm_tlast,

    // bram for tap RAM
    output  wire [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  wire [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,
    
    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);

    // write your code here!
    reg [31:0] map [0:72];
    reg [31:0] xin [0:10];
    reg [3:0] tapwe;
    reg ssready;
    reg [3:0] state,next;
	reg [3:0] count; 
	reg [3:0] count1;
	reg [3:0] datawe;
	reg [3:0] count2;
    reg flag;
    reg   [(pDATA_WIDTH-1):0] smtdata;
	parameter [3:0] s0=4'b0000,
					write=4'b0001,
					read=4'b0010,
					s3=4'b0011,
                    s4=4'b0100,
                    s5=4'b0101,
                    s6=4'b0110,
                    s7=4'b0111,
                    s8=4'b1000,
                    s9=4'b1001;
    
    
    assign awready = (!axis_rst_n) ? 0: awvalid ;
    assign wready = (!axis_rst_n) ? 0: wvalid ;
    assign rvalid = (!axis_rst_n) ? 0: rready ;
    assign arready = (!axis_rst_n) ? 0: arvalid ;
	assign tap_WE = tapwe;
	assign tap_EN = (rvalid & rready) ? 1 : 0;
	assign tap_A = (tap_WE==4'b1111) ? araddr-32 : 
	               (state==s5)? count<<2:0;
	assign tap_Di = (tap_WE==4'b1111) ? map[araddr] : 0;
	assign rdata=(rready&rvalid)? map[araddr] : 0;
	assign ss_tready = (!axis_rst_n)? 0: ssready;
    assign sm_tdata  = smtdata;
    assign sm_tvalid = (state==s7)? 1:0;
    assign sm_tlast = (sm_tvalid&&flag) ? 1:0;
    integer i;
    
	
	assign data_WE  = (arready) ? 4'b1111:
	                  (state==s4) ? 4'b1111:
	                  (state==s6) ? 4'b1111 :0 ;
	assign data_EN = 1;
	assign data_A = tap_A;
	assign data_Di = (data_WE)? ss_tdata: 0;
	
	
	always@(posedge axis_clk)
	begin
		if(!axis_rst_n)state <= s0;
		else 		   state<=next;
	end
    always@(*)begin
        next=3'b000;
		case(state)
			s0 : if(!axis_rst_n) next = s0;
				 else next = s3;
			write : if (map[0]==1) next = s4;
			        else if (wvalid & wready) next = write;
			        else if(count==10) next= read; 
					else next = s3;
			read : if (flag) next = s9; 
			       else if (wvalid & wready) next =write;
			       else if (arvalid &arready) next = read;
				   else  next = s3;
			s3 : if(wvalid & wready) next = write;
				 else if (rvalid & rready) next = read;
				 else next = s3;
            s4 : next = s5;
            s5 : if(count==10) next = s6;
                 else next=s5;
            s6 : next=s7;
            s7: if(sm_tlast)next=s8;
                else next=s5;
            s8 :next=read;
            s9: next=read;
			default :next = 3'b000;
		endcase
	end
    always@(posedge axis_clk)
    begin
        case(state)
            s0:
            begin
                for(i=0;i<73;i=i+1)
                    map[i]<= 0;
                for(i=0;i<11;i=i+1)
                    xin[i]<= 0;
                tapwe <= 0;
                count<=0;
                ssready<=0;
                count1<=0;
                smtdata<=0;
                datawe<=0;
                flag<=0;
                count2<=0;
            end
            write:
            begin
                if(count==10)begin 
                flag<=0;
                count<=0;
                count1<=0;
                count2<=0;
                ssready<=0;
                tapwe<= 4'b1111;
                map[awaddr]<= wdata;
                end
				else begin 
				count2<=0;
				count1<=0;
				flag<=0;
				count<=count+1;
				ssready<=0;
				tapwe<=0;
				map[awaddr]<= wdata;
				end
            end
            read:
            begin
                tapwe<=4'b1111;
                ssready<=0;
            end
            s3: 
            begin
                for(i=0;i<73;i=i+1) map[i]<=map[i];
				tapwe<=0;
				ssready<=0;
            end
            s4 : 
            begin
                tapwe<= 0;
                map[0]<=0;
                count<=0;
                count1<=count1+1;
                ssready<=0;
                xin[0]<= data_Di;
                datawe<=4'b1111;
            end
            s5 :
            begin
                ssready<=0;
                if(count1==10)count1<=0;
                else count1<=count1+1;
                if(count==10)count<=0;
                else count<=count+1;
                if(count1==1)count2<=0;
                else count2<=count2+1;
                if(count==0) smtdata<= 0;
                else smtdata<=xin[count2]*tap_Do+smtdata;
                if(count1==9) ssready<=1;
                else ssready<=0;
                if(count==9) datawe<=4'b1111;
                else datawe<=0;
            end
            s6 : 
            begin
                //count1<=0;
                smtdata<= xin[10]*tap_Do+smtdata;
                ssready<=0;
                xin[1]<=xin[0];
                xin[2]<=xin[1];
                xin[3]<=xin[2];
                xin[4]<=xin[3];
                xin[5]<=xin[4];
                xin[6]<=xin[5];
                xin[7]<=xin[6];
                xin[8]<=xin[7];
                xin[9]<=xin[8];
                xin[10]<=xin[9];
            
            end
            s7: begin
                xin[0]<= data_Do;
                smtdata<= 0;
                if(ss_tlast) flag<=1;
                else flag<=0;
            end
            s8: map[0]<=2;
            s9: map[0]<=4;
            default: 
            begin
                for(i=0;i<73;i=i+1) map[i]<=map[i];
            end
        endcase
    end
    
endmodule
