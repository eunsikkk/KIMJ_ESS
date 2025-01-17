%% 1. 기본 설정 및 파일 읽기
clc; clear; close all

% 기본 경로 및 폴더 지정
baseDir    = 'G:\공유 드라이브\BSL_Data2\한전_김제ESS';
kimjFolder = '202106_KIMJ';
dateFolder = '20210602';
data_folder = fullfile(baseDir, kimjFolder, dateFolder);

% 파일명 지정 (예: 20210602_LGCHEM_RARD.csv)
filename   = '20210602_LGCHEM_RARD.csv';
filePath   = fullfile(data_folder, filename);

% 부가정보(예: 1~4행)를 건너뛰고, 5번째 행을 변수명으로 사용 (즉, n_hd = 4)
n_hd = 4;

% readtable을 이용하여 파일 읽기
T = readtable(filePath, 'FileType', 'text', ...
    'NumHeaderLines', n_hd, ...         % 1~4행 건너뛰고, 5번째 행을 변수명으로 사용
    'ReadVariableNames', true, ...
    'PreserveVariableNames', true);

%% 2. 랙 번호별로 그룹화하기
% 5번째 행의 헤더에 "Rack No."라는 변수가 있다고 가정합니다.
uniqueRacks = unique(T.('Rack No.'));

%% 3. 사용자가 플롯할 셀 번호 입력 (1~14)
cellNumber = input('플롯할 셀 번호를 입력하세요 (1 ~ 14): ');
if cellNumber < 1 || cellNumber > 14
    error('셀 번호는 1에서 14 사이여야 합니다.');
end
% 셀 번호를 두 자리 문자열로 변환 (예: 1 -> '01')
cellStr = sprintf('%02d', cellNumber);
% 변수명 생성 (예: 'Cell#01(V)')
varName = ['Cell#' cellStr '(V)'];
fprintf('선택된 변수명: %s\n', varName);

%% 4. 각 랙별로 그룹화된 데이터에서 선택된 셀의 전압을 플롯
for k = 1:length(uniqueRacks)
    rack = uniqueRacks(k);
    % 해당 랙 번호에 해당하는 데이터 인덱스
    idx = T.('Rack No.') == rack;
    T_rack = T(idx, :);
    
    % 플롯 생성: Time vs 선택한 셀의 전압
    figure;
    plot(T_rack.Time, T_rack.(varName), 'LineWidth', 1.5);
    xlabel('Time');
    ylabel(varName);
    title(sprintf('Time vs %s for Rack %d', varName, rack));
    grid on;
end
