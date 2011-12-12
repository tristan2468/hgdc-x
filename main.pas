{
 * Copyright (c) 2011, Tristan Linnell <tris@canthack.org>
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
}

// hgdc-x Cross Platform hgd client written in Lazarus/Freepascal
// main.pas - HGD Client GUI

unit Main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, XMLPropStorage, Buttons, Grids, ComCtrls, HGDClient,
  LastFM, Settings, About, LCLProc;

type

  { TfrmMain }

  TfrmMain = class(TForm)
    ApplicationProperties1: TApplicationProperties;
    Bevel1: TBevel;
    btnSkip: TBitBtn;
    btnPause: TBitBtn;
    btnQueue: TBitBtn;
    btnCrapSong: TBitBtn;
    gbNowPlaying: TGroupBox;
    imInsecure: TImage;
    imSecure: TImage;
    imVoteOff: TImage;
    imLogin: TImage;
    imNowPlaying: TImage;
    imAbout: TImage;
    lblSampleRate: TLabel;
    lblGenre: TLabel;
    lblDuration: TLabel;
    lblBitrate: TLabel;
    lblNoAlbumArt: TLabel;
    lblStatus: TLabel;
    lblYear: TLabel;
    lblTitle: TLabel;
    lblArtist: TLabel;
    lblAlbum: TLabel;
    lblNoPlaylist: TLabel;
    OpenDialog1: TOpenDialog;
    pbarUpload: TProgressBar;
    sgPlaylist: TStringGrid;
    tmrPlaylist: TTimer;
    tmrState: TTimer;
    XMLPropStorage1: TXMLPropStorage;
    procedure btnCrapSongClick(Sender: TObject);
    procedure ApplyChanges;
    procedure btnPauseClick(Sender: TObject);
    procedure btnSkipClick(Sender: TObject);
    procedure btnQueueClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormDropFiles(Sender: TObject; const FileNames: array of String);
    procedure FormShow(Sender: TObject);
    procedure imAboutClick(Sender: TObject);
    procedure imLoginClick(Sender: TObject);
    procedure sgPlaylistDrawCell(Sender: TObject; aCol, aRow: Integer;
      aRect: TRect; aState: TGridDrawState);
    procedure tmrPlaylistTimer(Sender: TObject);
    procedure tmrStateTimer(Sender: TObject);
  private
    { private declarations }
    FClient: THGDClient;
    FLastFM: TLastFM;
    FCurrentlyDisplayedArtwork: string;
    FArtworkAttempts: integer;
    FDebug: boolean;
    frmSettings: TFrmSettings;
    procedure DisableAllGUI;
    procedure EnableAllGUI;
    procedure Log(Message: string);
    procedure ProgressCallback(Percentage: integer);
    procedure ShowNowPlaying(b: boolean);
    procedure ShowStatus(Msg: string; Error: boolean);

  public
    { public declarations }
  end;

var
  frmMain: TfrmMain;

const
  MAX_ARTWORK_ATTEMPTS = 3;
  VERSION = '0.5.dev';

implementation

{$R *.lfm}

{ TfrmMain }

procedure TfrmMain.ApplyChanges;
begin
  tmrPlaylist.Enabled := False;
  tmrState.Enabled := False;

  ShowStatus('Applying...', False);
  frmSettings.XMLPropStorage1.Save();

  FClient.HostAddress := frmSettings.edtHost.Text;
  FClient.HostPort := frmSettings.edtPort.Text;
  FClient.UserName := frmSettings.edtUser.Text;
  FClient.Password := frmSettings.edtPwd.Text;
  FClient.SSL := frmSettings.chkSSL.Checked;

  FClient.ApplyChanges();

  tmrState.Enabled := True;
  tmrPlaylist.Enabled := True;
  tmrPlayListTimer(Self);
end;

procedure TfrmMain.btnPauseClick(Sender: TObject);
begin
  if sgPlaylist.RowCount > 1 then
    FClient.Pause();
end;

procedure TfrmMain.btnSkipClick(Sender: TObject);
begin
  if sgPlaylist.RowCount > 1 then
    FClient.SkipTrack();
end;

procedure TfrmMain.btnCrapSongClick(Sender: TObject);
begin
  if sgPlaylist.RowCount > 1 then
    if FClient.VoteOff(StrToIntDef(sgPlaylist.Cells[0,1], -1)) then
      imVoteOff.Visible := True;
end;

procedure TfrmMain.btnQueueClick(Sender: TObject);
var
  i: integer;
begin
  DisableAllGUI();

  if OpenDialog1.Execute() then
  begin
    Screen.Cursor := crHourglass;

    for i := 0 to OpenDialog1.Files.Count - 1 do
    begin
      if FClient.State < hsAuthenticated then
        Break;

      pbarUpload.Position := pbarUpload.Min;
      pbarUpload.Visible := True;
      btnQueue.Visible := False;
      FClient.QueueSong(OpenDialog1.Files[i]);
      pbarUpload.Visible := False;
      btnQueue.Visible := True;
    end;

    Screen.Cursor := crDefault;
  end;

  EnableAllGUI();
end;

procedure TfrmMain.DisableAllGUI;
begin
  tmrPlayList.Enabled := False;
  tmrState.Enabled := False;
  btnQueue.Enabled := False;
  btnCrapSong.Enabled := False;
  btnSkip.Enabled := False;
  btnPause.Enabled := False;
  imLogin.Enabled := False;
  frmSettings.btnHGDLogin.Enabled := False;
end;

procedure TfrmMain.EnableAllGUI;
begin
  btnQueue.Enabled := True;
  btnCrapSong.Enabled := True;
  btnSkip.Enabled := True;
  btnPause.Enabled := True;
  imLogin.Enabled := True;
  frmSettings.btnHGDLogin.Enabled := True;
  tmrPlayList.Enabled := True;
  tmrPlayListTimer(Self);
  tmrState.Enabled := True;
  tmrStateTimer(Self);
  Self.SetFocus;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  {$IFDEF WINDOWS}
  if ForceDirectoriesUTF8(GetAppConfigDirUTF8(False)) then
  begin
    frmSettings.XMLPropStorage1.FileName := GetAppConfigDirUTF8(False) + 'settings.xml'
    XMLPropStorage1.FileName := GetAppConfigDirUTF8(False) + 'settings.xml'
  end
  else
  begin
    XMLPropStorage1.Active := False;
    frmSettings.XMLPropStorage1.Active := False;
  end;
  {$ENDIF WINDOWS}
  Self.Caption := Self.Caption + ' ' +  VERSION;
  FArtworkAttempts := 0;
  FCurrentlyDisplayedArtwork := '';
  FDebug := Application.HasOption('d', 'debug');
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FLastFM.Free();
  FClient.Free();
  frmSettings.Free();
end;

procedure TfrmMain.FormDropFiles(Sender: TObject;
  const FileNames: array of String);
var
  i: integer;
begin
  if FClient.State >= hsAuthenticated then
  begin
    DisableAllGUI();
    Screen.Cursor := crHourglass;

    for i := Low(Filenames) to High(Filenames) do
    begin
      if FClient.State < hsAuthenticated then
        Break;

      pbarUpload.Position := pbarUpload.Min;
      pbarUpload.Visible := True;
      FClient.QueueSong(Filenames[i]);
      pbarUpload.Visible := False;
    end;

    Screen.Cursor := crDefault;
    EnableAllGUI();
  end;
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  frmSettings := TFrmSettings.Create(Self);
  frmSettings.ShowModal();

  FClient := THGDClient.Create(frmSettings.edtHost.Text,
    frmSettings.edtPort.Text, frmSettings.edtUser.Text, frmSettings.edtPwd.Text,
    frmSettings.chkSSL.Checked, FDebug);

  FClient.ProgressCallBack := @ProgressCallback;

  FLastFM := TLastFM.Create(frmSettings.edtLastFMUser.Text,
    GetAppConfigDirUTF8(False), FDebug);

  tmrPlaylistTimer(Self);

end;

procedure TfrmMain.imAboutClick(Sender: TObject);
begin
  frmAbout.Show();
end;

procedure TfrmMain.imLoginClick(Sender: TObject);
begin
  if mrOK = frmSettings.ShowModal() then
    ApplyChanges();
end;

procedure TfrmMain.sgPlaylistDrawCell(Sender: TObject; aCol, aRow: Integer;
  aRect: TRect; aState: TGridDrawState);
var
  S: string;
begin
  if (aRow = 1) and (aCol > 0) then
  begin
    TStringGrid(Sender).Canvas.Brush.Color := clHighlight;
    TStringGrid(Sender).Canvas.Font.Color := clHighlightText;
    TStringGrid(Sender).Canvas.FillRect(aRect);

    S := TStringGrid(Sender).Cells[aCol, aRow];
    TStringGrid(Sender).Canvas.TextOut(aRect.Left + 2, aRect.Top + 2, S);
  end;
end;

procedure TfrmMain.ProgressCallback(Percentage: integer);
begin
  pBarUpload.Position := Percentage;
  Application.ProcessMessages();
end;

procedure TfrmMain.tmrPlaylistTimer(Sender: TObject);
var
  PL: TPlaylist;
  i: integer;
begin
  tmrPlaylist.Enabled := False;
  PL := nil;

  if Assigned(FClient) and (FClient.State >= hsConnected) then
  begin
    FClient.GetPlaylist(PL);

    if Length(PL) > 0 then
    begin
      //There are some items in the playlist
      btnSkip.Enabled := FClient.State >= hsAuthenticated;
      btnPause.Enabled := FClient.State >= hsAuthenticated;
      btnCrapSong.Enabled := FClient.State >= hsAuthenticated;

      sgPlaylist.RowCount := 1;

      for i := 0 to Length(PL) - 1 do
      begin
        sgPlaylist.RowCount := sgPlaylist.RowCount + 1;
        sgPlaylist.Cells[0, sgPlaylist.RowCount -1] := IntToStr(PL[i].Number);

        if PL[i].Title <> '' then
          sgPlaylist.Cells[1, sgPlaylist.RowCount -1] := PL[i].Title
        else
          sgPlaylist.Cells[1, sgPlaylist.RowCount -1] := PL[i].Filename;

        sgPlaylist.Cells[2, sgPlaylist.RowCount -1] := PL[i].Artist;
        sgPlaylist.Cells[3, sgPlaylist.RowCount -1] := PL[i].Album;
        sgPlaylist.Cells[4, sgPlaylist.RowCount -1] := PL[i].User;
        lblNoPlaylist.Visible := False;

        //Display now playing info
        if (i = 0) then
        begin
          imVoteOff.Visible := PL[i].Voted;

          if PL[i].Title <> '' then
            lblTitle.Caption := PL[i].Title
          else
            lblTitle.Caption := PL[i].Filename;

          lblArtist.Caption := PL[i].Artist;
          lblAlbum.Caption := PL[i].Album;
          lblGenre.Caption := PL[i].Genre;

          if PL[i].Year > 0 then
            lblYear.Caption := IntToStr(PL[i].Year)
          else
            lblYear.Caption := '';

          if (PL[i].Artist <> '') and (PL[i].Album <> '') then
          begin
            if ((PL[i].Artist + ':' + PL[i].Album) <>
              FCurrentlyDisplayedArtwork) then
            begin
              //Playing track has changed, get artwork
              imNowPlaying.Visible := True;
              Bevel1.Visible := True;

              Log('Attempt ' + IntToStr(FArtworkAttempts + 1) +
                ' at album art fetching.');

              if FLastFM.GetAlbumArt(PL[i].Artist, PL[i].Album, szMedium,
                  imNowPlaying) then
              begin
                FCurrentlyDisplayedArtwork := PL[i].Artist + ':' + PL[i].Album;
                FArtworkAttempts := 0;
              end
              else
              begin
                //Couldn't get artwork, so hide it
                Inc(FArtworkAttempts);
                imNowPlaying.Visible := False;
                lblNoAlbumArt.Visible := True;
              end;

              if (FArtworkAttempts = MAX_ARTWORK_ATTEMPTS) then
              begin
                Log('Too many artwork attempts, not trying again.');
                FCurrentlyDisplayedArtwork := PL[i].Artist + ':' + PL[i].Album;
                FArtworkAttempts := 0;
              end;
            end;
          end
          else
          begin
            //No album information to get art with
            Log('No album information to get art with.');
            imNowPlaying.Visible := False;
            lblNoAlbumArt.Visible := True;
          end;
        end;
      end;
    end
    else
    begin
      //Nothing playing
      Log('Nothing is playing.');
      sgPlaylist.RowCount := 1;
      lblTitle.Caption := '';
      lblArtist.Caption := '';
      lblAlbum.Caption := '';
      lblGenre.Caption := '';
      lblBitrate.Caption := '';
      lblYear.Caption := '';
      lblSampleRate.Caption := '';
      lblDuration.Caption := '';
      lblNoPlaylist.Visible := True;
      btnSkip.Enabled := False;
      btnPause.Enabled := False;
      btnCrapSong.Enabled := False;
      FCurrentlyDisplayedArtwork := '';
      imNowPlaying.Picture.Clear;
      imNowPlaying.Visible := False;
      Bevel1.Visible := False;
      lblNoAlbumArt.Visible := False;
      imVoteOff.Visible := False;
    end;
  end
  else
    sgPlaylist.RowCount := 1;

  tmrPlaylist.Enabled := True;
end;

procedure TfrmMain.ShowStatus(Msg: string; Error: boolean);
begin
  if Error then
  begin
    lblStatus.Font.Color := clRed;
  end
  else
  begin
    lblStatus.Font.Color := clBlue;
  end;

  lblStatus.Caption := Msg;
end;

procedure TfrmMain.tmrStateTimer(Sender: TObject);
var
  ErrorState: boolean;
begin
  if Assigned(FClient) then
  begin
    tmrState.Enabled := False;
    ErrorState := Pos('error',
      LowerCase(FClient.StatusMessage)) > 0;

    ShowStatus(FClient.StatusMessage, ErrorState);

    if (FClient.State < hsConnected) and (not frmSettings.Visible) and
      (mrOK = frmSettings.ShowModal()) then
    begin
      ApplyChanges();
      Exit();
    end;

    imSecure.Visible := FClient.Encrypted;
    imInsecure.Visible := not FClient.Encrypted;

    if (not FClient.Encrypted) and (frmSettings.chkSSL.Checked) then
      frmSettings.chkSSL.Font.Style:= [fsStrikeOut]
    else
      frmSettings.chkSSL.Font.Style:= [];

    btnQueue.Enabled := FClient.State >= hsAuthenticated;
    ShowNowPlaying(FClient.State >= hsConnected);

    btnSkip.Visible := FClient.State >= hsAdmin;
    btnPause.Visible := FClient.State >= hsAdmin;

    tmrState.Enabled := True;
  end;
end;

procedure TfrmMain.ShowNowPlaying(b: boolean);
begin
  gbNowPlaying.Visible := b;
end;

procedure TfrmMain.Log(Message: string);
begin
  if FDebug then
    DebugLn(Self.ClassName + #9 + Message);
end;

end.
