unit ufrmMain;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Controls,
  Forms,
  StdCtrls,
  SynEdit,
  SysUtils,
  ComCtrls,
  Clipbrd,
  ExtCtrls,
  SynHighlighterPas;

type

  { TfrmMain }

  TfrmMain = class(TForm)
    ImageList1: TImageList;
    memString: TMemo;
    pnlTop: TPanel;
    pnlLeft: TPanel;
    pnlRight: TPanel;
    sePascal: TSynEdit;
    Splitter1: TSplitter;
    SynPasSyn1: TSynPasSyn;
    ToolBar1: TToolBar;
    tbClear: TToolButton;
    tbCopyPascal: TToolButton;
    ToolButton6: TToolButton;
    tbExit: TToolButton;
    procedure memStringChange(Sender: TObject);
    procedure sePascalChange(Sender: TObject);
    procedure tbClearClick(Sender: TObject);
    procedure tbCopyPascalClick(Sender: TObject);
    procedure tbExitClick(Sender: TObject);
    procedure tbUndoClick(Sender: TObject);
    procedure tbRedoClick(Sender: TObject);
  private
    userStringName: string;
    procedure PerformUpdateMemoToPascal;
    procedure PerformUpdatePascalToMemo;
    procedure ExtractVariableName;
  public

  end;

var
  frmMain: TfrmMain;

implementation

{$R *.lfm}

{ TfrmMain }

function plainTextToPascal(const MultilineInput: string; const VariableName: string): string;
var
  Lines: TStringList;
  i: integer;
  EscapedLine: string;
begin
  Lines := TStringList.Create;

  Lines.Text := MultilineInput;
  Result := VariableName + ' := ';
  for i := 0 to Lines.Count - 1 do
  begin
    EscapedLine := StringReplace(Lines[i], '''', '''''', [rfReplaceAll]);
    EscapedLine := StringReplace(EscapedLine, #9, ''' + #9 + ''', [rfReplaceAll]);
    { #todo -oTony : consider the empty ''; this still puts at the end of the string after multiple consecutive sLineBreak }
    if i > 0 then
      Result := Result + ' + sLineBreak' + #13#10;
    if EscapedLine <> '' then
      Result := Result + '''' + EscapedLine + ''''
    else if i = Lines.Count - 1 then
      Result := Result + '''''';
  end;
  Result := Result + ';';
  Lines.Free;
end;

{ #todo -oTony : I don't love this function.  Took me hours to make work... I feel like there is a much cleaner and simpler way.  May try rewrite again soon. }
// While it works there was an issue I found BUT DON"T FORGET I CHANGED TO "CAPTURING CHARACTERS BETWEEN QUOTES" BECAUSE YOUR CLEAN IDEA CAUSED ISSUES WITH A PLUS SIGN!
// JUST LEAVE ALONE FOR NOW!
function pascalToPlainText(const PascalInput: string; out VariableName: string): string;
var
  i, PosAssignment: integer;
  TempStr, Segment: string;
  Segments: TStringList;
  InQuotes: boolean;
begin
  Result := '';
  InQuotes := False;
  Segments := TStringList.Create;
  try
    // Remove actual new lines from the Pascal input to work with a single line
    TempStr := StringReplace(PascalInput, #13#10, '', [rfReplaceAll]);
    TempStr := StringReplace(TempStr, #10, '', [rfReplaceAll]);
    TempStr := StringReplace(TempStr, #13, '', [rfReplaceAll]);

    // Find the assignment variable and remove it along with the ending semicolon
    PosAssignment := Pos(':=', TempStr);
    if PosAssignment > 0 then
    begin
      VariableName := Trim(Copy(TempStr, 1, PosAssignment - 1));
      if VariableName = '' then
        VariableName := 'MultiLineString';
      TempStr := Copy(TempStr, PosAssignment + 2, Length(TempStr));
      TempStr := Trim(TempStr);
      if RightStr(TempStr, 1) = ';' then
        Delete(TempStr, Length(TempStr), 1);
    end else
      VariableName := 'MultiLineString';

    // Split the input into segments based on single quotes
    i := 1;
    while i <= Length(TempStr) do
    begin
      if TempStr[i] = '''' then
      begin
        if InQuotes then
        begin
          // Handle escaped quotes within quoted text
          // still an issue sometimes when something is not properly escaped it starts returning text outside of quotes
          // had an idea to rework... will come back and tweak i suppose
          if (i < Length(TempStr)) and (TempStr[i + 1] = '''') then
          begin
            Segment := Segment + '''';
            Inc(i);
          end else begin
            // End of quoted section
            InQuotes := False;
            Segments.Add(Segment);
            Segment := '';
          end;
        end else begin
          // Start of quoted section
          InQuotes := True;
          Segment := ''; // Clear any previous segment since we are only interested in quoted text
        end;
      end else if InQuotes then
      begin
        // Inside quotes, collect characters
        Segment := Segment + TempStr[i];
      end else if not InQuotes then
      begin
        // Ignore everything outside quotes
        { #todo -oTony : what if user types a #13 or #10 in the synedit.... ill handle this too next. }
        //StringReplace(TempStr, 'slinebreak','slinebreak',[rfIgnoreCase]);

        if UpCase(Copy(TempStr, i, 10)) = 'SLINEBREAK' then
        begin
          Segments.Add(#13#10); // Add actual line break
          Inc(i, 9); // Skip 'sLineBreak' .....
        end;
      end;
      Inc(i);
    end;

    // add remaining segment if still in quotes
    if InQuotes and (Segment <> '') then
      Segments.Add(Segment);

    // combining all of the segments...
    for i := 0 to Segments.Count - 1 do
    begin
      Result := Result + Segments[i];
    end;
  finally
    Segments.Free;
  end;
end;

{ #todo -oTony : Reconsider wether it should even have a complete string with Var name and assignment in the first place.   I guess it is handy if I am gonna copy and paste an entire string back and forth I can easily retain the variable name..... hmmmm.  Need to fix it if I keep it. }
procedure TfrmMain.ExtractVariableName;
var
  PosAssignment: integer;
  TempStr: string;
begin
  TempStr := Trim(sePascal.Lines.Text);
  PosAssignment := Pos(':=', TempStr);
  if PosAssignment > 0 then
  begin
    userStringName := Trim(Copy(TempStr, 1, PosAssignment - 1));
    if userStringName = '' then
      userStringName := 'MultiLineString';
  end else
    userStringName := 'MultiLineString';
end;

procedure TfrmMain.PerformUpdateMemoToPascal;
begin
  { #todo -oTony : Probably implement some sort of small delay when updating the TMemo or TSynEdit so if it is a long string you can process more efficiently rather than on each change.  For now this works good. }
  if sePascal.Focused then Exit;
  ExtractVariableName;
  sePascal.Lines.Text := plainTextToPascal(memString.Lines.Text, userStringName);
end;

procedure TfrmMain.PerformUpdatePascalToMemo;
begin
  if memString.Focused then Exit;
  ExtractVariableName;
  memString.Lines.Text := pascalToPlainText(sePascal.Lines.Text, userStringName);
end;

procedure TfrmMain.memStringChange(Sender: TObject);
begin
  PerformUpdateMemoToPascal;
end;

procedure TfrmMain.sePascalChange(Sender: TObject);
begin
  PerformUpdatePascalToMemo;
end;

procedure TfrmMain.tbClearClick(Sender: TObject);
begin
  memString.Lines.Clear;
  sePascal.Lines.Clear;
end;

procedure TfrmMain.tbCopyPascalClick(Sender: TObject);
begin
  Clipboard.AsText := sePascal.Lines.Text;
end;

procedure TfrmMain.tbExitClick(Sender: TObject);
begin
  Application.Terminate;
end;
{ #todo -oTony : Lets figure out the start and stop undo blocks of TSynEdit so I can make changes in either the memo or the synedit and still be able to undo them in either.  So use the programatically synedit changes as the undo blocks that will of course also effect the memo.... or that may be my approach.  Might revisit. }
procedure TfrmMain.tbUndoClick(Sender: TObject);
begin
  if sePascal.CanUndo then
    sePascal.Undo;
end;

procedure TfrmMain.tbRedoClick(Sender: TObject);
begin
  if sePascal.CanRedo then
    sePascal.Redo;
end;

end.
