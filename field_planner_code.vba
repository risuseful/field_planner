Option Explicit

Private Sub CommandButton1_Click()

'Author: Akmal Aulia, 12JAN2017











'******************************************
'//-----------define variables-------------

'define arrays
Dim rat() As Double, cum() As Double

'define double
Dim prat() As Double, pcum() As Double 'proposed rates and cumulatives
Dim nom_rat() As Double, gap As Double, rlim As Double, pcum_temp As Double
Dim gap_tol As Double, maxContrib() As Double, base_rat() As Double, prat_temp As Double
Dim sumContrib As Double, sumContrib2 As Double, accumFac As Double
Dim rlim_mat() As Double
Dim m As Double, b As Double, co2() As Double

'define integers
Dim i As Integer, j As Integer
Dim NTC As Integer, NWEL As Integer, NNOM As Integer, k As Integer
Dim inputFormat As Integer

'define worksheets
Dim wsRat As Worksheet, wsNOM As Worksheet, wsResult As Worksheet
Dim wsReport As Worksheet, wsDEBUG As Worksheet, wsConf As Worksheet
Dim wsTC As Worksheet, wsG As Worksheet

'define string
Dim welnam() As String

'define date
Dim avail_dat() As Variant, nom_dat() As Variant

'set worksheets
Set wsConf = Sheets("Config")
Set wsRat = Sheets("Rates")
Set wsNOM = Sheets("Nomination")
Set wsResult = Sheets("Sales")
Set wsReport = Sheets("Report")
Set wsTC = Sheets("Type Curves")
Set wsDEBUG = Sheets("DEBUG")
Set wsG = Sheets("Gross")

'-----------define variables-------------//
'******************************************











'******************************************
'//-----------Refresh and format output sheets-------------

wsResult.Cells.Clear
wsResult.Cells.Interior.ColorIndex = 56
wsResult.Cells.Font.ColorIndex = 2

wsReport.Cells.Clear
wsReport.Cells.Interior.ColorIndex = 56
wsReport.Cells.Font.ColorIndex = 2

wsTC.Cells.Clear
wsTC.Cells.Interior.ColorIndex = 56
wsTC.Cells.Font.ColorIndex = 2

wsG.Cells.Clear
wsG.Cells.Interior.ColorIndex = 56
wsG.Cells.Font.ColorIndex = 2

'-----------Refresh and format output sheets-------------//
'******************************************















'******************************************
'//-----------Obtain config params-------------

gap_tol = wsConf.Cells(9, 3) 'gap tolerance

m = wsConf.Cells(12, 3) 'shrinkage slope
b = wsConf.Cells(13, 3) 'shrinkage intercept

'obtain input format (1=monthly, 2=yearly, default=monthly)
accumFac = 30
    
'-----------Obtain config params-------------//
'******************************************









'******************************************
'//-----------Obtain input sizes-------------

'find NROW: number of rows in "Rates" sheet
NTC = 4 'use 2 to avoid column names
Do While wsRat.Cells(NTC, 1) <> ""
    NTC = NTC + 1
Loop
NTC = NTC - 4

'find NWEL: number of rows and/or platforms in "Rates" sheet
NWEL = 1 'use 2 to avoid date in first row
Do While wsRat.Cells(3, NWEL) <> ""
    NWEL = NWEL + 1
Loop
NWEL = NWEL - 1

'find how many rows in sheet "Nomination"
NNOM = 2 'use 2 to avoid date in first row
Do While wsNOM.Cells(NNOM, 1) <> ""
    NNOM = NNOM + 1
Loop
NNOM = NNOM - 2

'-----------Obtain input sizes-------------//
'******************************************








'******************************************
'//-----------Populate input data (type curve)-------------

'set dimension for rat() and cum()
ReDim rat(NTC, NWEL)
ReDim cum(NTC, NWEL)
ReDim co2(NWEL)

'store rates from "Rates" sheet in "rat" matrix, and store the cum in "cum" matrix
For i = 1 To NTC
    For j = 1 To NWEL
    
        'initialize
        rat(i, j) = 0
        cum(i, j) = 0
    
        rat(i, j) = wsRat.Cells(i + 3, j)
        
        'stor cum as well
        If i = 1 Then
            cum(i, j) = rat(i, j) * accumFac / 1000 'cum is based on monthly rate and has "bcf" unit.
        Else
            cum(i, j) = cum(i - 1, j) + rat(i, j) * accumFac / 1000
        End If
    
    Next j
Next i

For j = 1 To NWEL
    co2(j) = wsRat.Cells(2, j)
Next j

'-----------Populate input data (type curve)-------------//
'******************************************









'******************************************
'//-----------Populate input data (well info)-------------

'store name and available date for each well/platform
ReDim welnam(NWEL)
ReDim avail_dat(NWEL)

For j = 1 To NWEL
    welnam(j) = wsRat.Cells(3, j)
    avail_dat(j) = wsRat.Cells(1, j)
    
    'replace empty date with 1-jan-1900
    If avail_dat(j) <> "" Then
        avail_dat(j) = avail_dat(j)
    Else
        avail_dat(j) = DateValue("Jan 1, 1900")
    End If
Next j

'-----------Populate input data (well info)-------------//
'******************************************









'******************************************
'//-----------Populate input data (nom)-------------

'store dates in nom_dat vector, and store rates in nom_rat vector
ReDim nom_dat(NNOM)
ReDim base_rat(NNOM)
ReDim nom_rat(NNOM)
ReDim maxContrib(NNOM)

For i = 1 To NNOM
    nom_dat(i) = wsNOM.Cells(i + 1, 1)
    base_rat(i) = wsNOM.Cells(i + 1, 2)
    nom_rat(i) = wsNOM.Cells(i + 1, 3)
    maxContrib(i) = wsNOM.Cells(i + 1, 4)
Next i

'-----------Populate input data (nom)-------------//
'******************************************









'******************************************
'//-----------Initialize output data-------------

'set dimension for prat and pcum
ReDim prat(NNOM, NWEL)
ReDim pcum(NNOM, NWEL)
ReDim rlim_mat(NNOM, NWEL)

'initialize matrix
For i = 1 To NNOM
    For j = 1 To NWEL
        prat(i, j) = 0
        pcum(i, j) = 0
        rlim_mat(i, j) = 0 'added on 06MAR2017: this matrix stores sales prod capacity
    Next j
Next i

'-----------Initialize output data-------------//
'******************************************









'**********************************************************************************************
'//-----------Find proposed rates and cumulatives for each well/platform-------------

'loop through nomination dates
For i = 1 To NNOM

    'initialize gap
    gap = 0

    'check gap
    gap = nom_rat(i) - base_rat(i)
    
    If gap >= gap_tol Then
        
        'gap must be capped to maxContrib (ex. max contribution from all proposed platforms/wells)
        If gap > maxContrib(i) Then
            gap = maxContrib(i)
        End If
        
        'ask for contributions from proposed wells/platforms
        For j = 1 To NWEL
        

            
            'based on current i^th date, is the well/platform already available?
            If nom_dat(i) >= avail_dat(j) Then
                
                'set temporary proposed rate as gap
                prat_temp = gap
                
                'evaluate cumulative of proposed rate
                If i > 1 Then
                    'removed (28FEB2017) -> pcum_temp = pcum(i - 1, j) + (accumFac / 1000) * prat_temp
                    pcum_temp = pcum(i - 1, j)
                Else
                    'removed (28FEB2017) -> pcum_temp = (accumFac / 1000) * prat_temp
                    pcum_temp = 0 'this line is actually not necessary; it was inialized to 0.
                End If
                
                'find rate limit (limited by type curve)
                rlim = rateLimit(pcum_temp, rat(), cum(), j, NTC)
                
                'removed (28FEB2017) -> 'maximize prat_temp
                'removed (28FEB2017) -> niter = 0 'initialize number of iterations
                'removed (28FEB2017) -> Do While prat_temp > rlim And niter <= MAXIT
                
                'removed (28FEB2017) ->     'update proposed rate
                'removed (28FEB2017) ->     prat_temp = rlim
                    
                'removed (28FEB2017) ->     'update cumulative of proposed rate
                'removed (28FEB2017) ->     pcum_temp = pcum(i - 1, j) + (accumFac / 1000) * prat_temp
                    
                'removed (28FEB2017) ->     'find rate limit
                'removed (28FEB2017) ->     rlim = rateLimit(pcum_temp, rat(), cum(), j, NTC)
                
                'removed (28FEB2017) ->     'update number of iterations
                'removed (28FEB2017) ->     niter = niter + 1
                'removed (28FEB2017) -> Loop
                
                'maximize prat_temp
                If prat_temp > rlim Then
                    prat_temp = rlim
                End If
                
                'now, we've got final prat_temp, let's assess the gap
                gap = gap - prat_temp
                
                'record final proposed rate and cum for this well/platform
                prat(i, j) = prat_temp
                pcum(i, j) = pcum_temp + (accumFac / 1000) * prat_temp
                rlim_mat(i, j) = rlim
                
                'check if gap is smaller than gap_tol
                If gap < gap_tol Then
                    Exit For 'go to next timestep of nomination
                End If 'else, go to next well
                
            Else
            
                'go to next well, since this well is not yet available
                'note: nothing to do here
                
            End If
                
        Next j
        
    End If

Next i

'-----------Find proposed rates and cumulatives for each well/platform-------------//
'**********************************************************************************************









'**********************************************************************************************
'//-----------Report proposed rates in sheet "Results"-------------

For i = 1 To NNOM
    
    'print column names
    If i = 1 Then
        wsResult.Cells(1, 1) = "Date"
        
        wsResult.Cells(1, 2) = "NOM"
        
        wsResult.Cells(1, 3) = "Base"
        
        wsResult.Cells(1, 4) = "TopUp"
        wsResult.Cells(1, 4).Interior.ColorIndex = 10
        
        wsResult.Cells(i, 5) = "Base + TopUp"
        
        wsResult.Cells(i, 5 + NWEL + NWEL + 1) = "Base + TopUp.[Cap]"
        wsResult.Cells(i, 5 + NWEL + NWEL + 1).Interior.ColorIndex = 5
        
        
        For j = 1 To NWEL
            wsResult.Cells(1, 5 + j) = welnam(j)
            wsResult.Cells(1, 5 + j).Interior.ColorIndex = 10
            
            'sales capacity
            wsResult.Cells(1, 5 + j + NWEL) = welnam(j) & " .[Cap]"
            wsResult.Cells(1, 5 + j + NWEL).Interior.ColorIndex = 3
        Next j
        
    End If

    
    
    'print dates
    wsResult.Cells(i + 1, 1) = nom_dat(i)
    
    'print NOM
    wsResult.Cells(i + 1, 2) = Round(nom_rat(i), 0)
    
    'print rate contribution
    sumContrib = 0
    sumContrib2 = 0
    For j = 1 To NWEL
        
        wsResult.Cells(i + 1, 5 + j) = Round(prat(i, j), 0)
        sumContrib = sumContrib + prat(i, j) 'sum rates from all wells/platforms
        
        'sales capacity
        wsResult.Cells(i + 1, 5 + j + NWEL) = Round(rlim_mat(i, j), 0)
        sumContrib2 = sumContrib2 + rlim_mat(i, j) 'sum capacity from all wells/platforms
        
    Next j
    
    'print
    wsResult.Cells(i + 1, 3) = Round(base_rat(i), 0)
    wsResult.Cells(i + 1, 4) = Round(sumContrib, 0)
    wsResult.Cells(i + 1, 5) = Round(sumContrib + base_rat(i), 0)
    wsResult.Cells(i + 1, 5 + NWEL + NWEL + 1) = Round(sumContrib2 + base_rat(i), 0)
    

    
    
Next i


'-----------Report proposed rates in sheet "Results"-------------//
'**********************************************************************************************



'**********************************************************************************************
'//-----------Report proposed rates in sheet "Gross"-------------

For i = 1 To NNOM
    
    'print column names
    If i = 1 Then
        
        wsG.Cells(1, 1) = "Date"
        
        wsG.Cells(1, NWEL + 2) = "TopUp"
        wsG.Cells(1, NWEL + 2).Interior.ColorIndex = 5
        
        wsG.Cells(1, NWEL + NWEL + 3) = "TopUp.[Cap]"
        wsG.Cells(1, NWEL + NWEL + 3).Interior.ColorIndex = 9
        
        
        For j = 1 To NWEL
            wsG.Cells(1, 1 + j) = welnam(j)
            wsG.Cells(1, 1 + j).Interior.ColorIndex = 10
            
            'sales capacity
            wsG.Cells(1, NWEL + 2 + j) = welnam(j) & " .[Cap]"
            wsG.Cells(1, NWEL + 2 + j).Interior.ColorIndex = 3
        Next j
        
    End If

    
    
    'print dates
    wsG.Cells(i + 1, 1) = nom_dat(i)
    
    'print rate contribution
    sumContrib = 0
    sumContrib2 = 0
    For j = 1 To NWEL
        
        'proposed rate
        wsG.Cells(i + 1, 1 + j) = Round(prat(i, j) / (m * co2(j) + b), 0)
        sumContrib = sumContrib + prat(i, j) / (m * co2(j) + b) 'sum rates from all wells/platforms
        
        'sales capacity
        wsG.Cells(i + 1, NWEL + 2 + j) = Round(rlim_mat(i, j) / (m * co2(j) + b), 0)
        sumContrib2 = sumContrib2 + rlim_mat(i, j) / (m * co2(j) + b) 'sum capacity from all wells/platforms
        
    Next j
    
    'print
    'wsResult.Cells(i + 1, 3) = Round(base_rat(i), 0)
    wsG.Cells(i + 1, NWEL + 2) = Round(sumContrib, 0)
    'wsResult.Cells(i + 1, 5) = Round(sumContrib + base_rat(i), 0)
    wsG.Cells(i + 1, NWEL + NWEL + 3) = Round(sumContrib2, 0)
    

    
    
Next i


'-----------Report proposed rates in sheet "Gross"-------------//
'**********************************************************************************************





'**********************************************************************************************
'//-----------Report well/platform proposed schedule in sheet "Report"-------------

'name columns
wsReport.Cells(1, 1) = "Well/Platform"
wsReport.Cells(1, 1).Interior.ColorIndex = 10

wsReport.Cells(1, 2) = "Schedule"
wsReport.Cells(1, 2).Interior.ColorIndex = 9

'report values
For j = 1 To NWEL
    For i = 1 To NNOM
        
        If prat(i, j) <> 0 Then
            wsReport.Cells(j + 1, 1) = welnam(j)
            wsReport.Cells(j + 1, 2) = nom_dat(i)
            Exit For
        End If
            
        
    Next i
Next j

'-----------Report well/platform proposed schedule in sheet "Report"-------------//
'**********************************************************************************************









'**********************************************************************************************
'//-----------Report type curves used in sheet "Type Curves"-------------


'report values
For j = 1 To NWEL
    For k = 1 To NTC
     
        'print column names
        If k = 1 Then
            wsTC.Cells(k, j + (j - 1)) = "cum(" & welnam(j) & ")"
            wsTC.Cells(k, 2 * j) = "rate(" & welnam(j) & ")"
        End If
        
        'print values
        wsTC.Cells(k + 1, j + (j - 1)) = Round(cum(k, j), 0)
        wsTC.Cells(k + 1, 2 * j) = Round(rat(k, j), 0)
        
    Next k
Next j

'-----------Report type curves used in sheet "Type Curves"-------------//
'**********************************************************************************************


'indicate completion
MsgBox "Done."

End Sub


Function rateLimit(pcum_temp As Double, rat() As Double, cum() As Double, j As Integer, NTC As Integer) As Double
'Purpose: find rate limited by type curve based on cum

    'define integer variable
    Dim k As Integer
    

    
    'debug
    rateLimit = 0
    
    If pcum_temp < cum(1, j) Then ' read: if cum is smaller than smallest cum available

        ' use rlim associated to smallest cum
        rateLimit = rat(1, j)

    ElseIf pcum_temp > cum(NTC, j) Then ' read: if cum is larger than largest cum available

        ' use rlim associated to largest cum
        rateLimit = rat(NTC, j)

    Else ' interpolate between lines

        For k = 1 To (NTC - 1)
            If cum(k, j) <= pcum_temp And cum(k + 1, j) >= pcum_temp Then
                
                If rat(k + 1, j) = rat(k, j) Then
                
                    'the rate at upper and lower time is the same, hence no need to interpolate
                    rateLimit = rat(k, j)
                    
                Else
                    
                    'interpolate
                    rateLimit = rat(k, j) + (rat(k + 1, j) - rat(k, j)) * (pcum_temp - cum(k, j)) / (cum(k + 1, j) - cum(k, j))
                    
                End If

            End If
        Next k

    End If

End Function




