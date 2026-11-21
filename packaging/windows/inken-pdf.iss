; Inken PDF — Windows kurulum betiği (Inno Setup 6).
; Derleme: ISCC.exe /DAppVersion=1.0.0 packaging\windows\inken-pdf.iss
; Önce: flutter build windows --release (apps/inken) ve VC++ çalışma
; zamanı DLL'leri Release klasörüne kopyalanmış olmalı (iş akışı yapar).

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define Release "..\..\apps\inken\build\windows\x64\runner\Release"

[Setup]
; Kimlik sabit kalmalı: güncellemeler aynı kurulumun üzerine gelir.
AppId={{A84AAF8B-EB89-446B-949A-6EE9B9F4E1BB}
AppName=Inken PDF
AppVersion={#AppVersion}
AppPublisher=Inken PDF
DefaultDirName={autopf}\Inken PDF
DefaultGroupName=Inken PDF
DisableProgramGroupPage=yes
OutputDir=..\..\dist
OutputBaseFilename=InkenPDF-Kurulum-{#AppVersion}
SetupIconFile=..\..\apps\inken\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\inken.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Yönetici değilse yalnızca bu kullanıcı için kurulabilsin (okul bilgisayarı).
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#Release}\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
Source: "..\..\LICENSE"; DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion

[Icons]
Name: "{group}\Inken PDF"; Filename: "{app}\inken.exe"
Name: "{autodesktop}\Inken PDF"; Filename: "{app}\inken.exe"; Tasks: desktopicon

[Registry]
; PDF'ler için "Birlikte aç → Inken PDF" (varsayılan uygulamayı değiştirmez).
Root: HKA; Subkey: "Software\Classes\Applications\inken.exe"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "Inken PDF"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Applications\inken.exe\SupportedTypes"; ValueType: string; ValueName: ".pdf"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\Applications\inken.exe\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\inken.exe"" ""%1"""
Root: HKA; Subkey: "Software\Classes\.pdf\OpenWithList\inken.exe"; ValueType: none; Flags: uninsdeletekey
; Inken varsayılan PDF uygulaması seçilince PDF'ler bu ProgID'yle açılır ve
; dosya ikonu (inken.exe içindeki IDI_PDF_FILE, kaynak kimliği 102) görünür.
Root: HKA; Subkey: "Software\Classes\InkenPDF.Document"; ValueType: string; ValueName: ""; ValueData: "PDF"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\InkenPDF.Document\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: """{app}\inken.exe"",-102"
Root: HKA; Subkey: "Software\Classes\InkenPDF.Document\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\inken.exe"" ""%1"""
Root: HKA; Subkey: "Software\Classes\.pdf\OpenWithProgids"; ValueType: string; ValueName: "InkenPDF.Document"; ValueData: ""; Flags: uninsdeletevalue

[Run]
Filename: "{app}\inken.exe"; Description: "{cm:LaunchProgram,Inken PDF}"; Flags: nowait postinstall skipifsilent
