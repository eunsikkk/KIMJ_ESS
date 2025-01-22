%% 1. 기본 설정 및 날짜 폴더 자동 검출
clc; clear; close all

baseDir    = 'G:\공유 드라이브\BSL_Data2\한전_김제ESS';
kimjFolder = '202106_KIMJ';
basePath   = fullfile(baseDir, kimjFolder);

% 폴더 내의 모든 폴더 목록 가져오기
allItems    = dir(basePath);
folderNames = {allItems([allItems.isdir]).name};


% 날짜 폴더들을 오름차순으로 정렬 (YYYYMMDD 형식이면 올바르게 정렬됨)
dateFolders = sort(folderNames);

%% 2. 원하는 기간 선택 (예: 20210615 ~ 20210622)
weekStart = '20210615';
weekEnd   = '20210615';  % 하루로 하고 싶으면 weekStart와 weekEnd를 동일하게 입력

% 문자열을 숫자로 변환하여 범위 비교 수행
weekFolders = dateFolders(cellfun(@(x) (str2double(x) >= str2double(weekStart)) && ...
                                       (str2double(x) <= str2double(weekEnd)), dateFolders));
                                   
fprintf('선택된 기간 폴더:\n');
disp(weekFolders);

% RBMS 파일의 파일명 패턴 
filePatternTemplate = '%s_LGCHEM_RBMS*.csv';

% 헤더 관련: 각 파일에서 11번째 줄이 변수명이 있는 것으로 가정
n_hd = 11;

%% 3. 여러 날짜 폴더의 모든 파일 데이터를 하나의 테이블(allData)에 누적
allData = table();

for i = 1:length(weekFolders)
    currDate   = weekFolders{i};  % 예: '20210615'
    data_folder = fullfile(baseDir, kimjFolder, currDate);
    
    % 파일 패턴 (예: '20210615_LGCHEM_RBMS*.csv')
    filePattern = fullfile(data_folder, sprintf(filePatternTemplate, currDate));
    fileList = dir(filePattern);
    
    for j = 1:length(fileList)
        fullFilePath = fullfile(fileList(j).folder, fileList(j).name);
        if ~exist(fullFilePath, 'file')
            warning('파일이 존재하지 않습니다: %s', fullFilePath);
            continue;
        end
        
        T = readtable(fullFilePath, 'FileType', 'text', ...
            'NumHeaderLines', n_hd, ...
            'ReadVariableNames', true, ...
            'PreserveVariableNames', true);
        allData = [allData; T];  %#ok<AGROW>
    end
end

%% 4. 유효 데이터 확인 및 Time 열 datetime 변환
if isempty(allData)
    error('선택한 기간(%s ~ %s)에 해당하는 유효 데이터가 없습니다.', weekStart, weekEnd);
end

% CSV 파일의 실제 시간 포맷에 맞게 InputFormat 수정 (예: 'yyyy-MM-dd HH:mm:ss')
try
    allData.Time = datetime(allData.Time, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
catch
    warning('Time 열의 datetime 변환에 실패했습니다. CSV 포맷을 확인하세요.');
end

%% 5. 매 초 단위로 그룹화: "Average C.V.(V)"와 SOC(%) 각각 평균 계산
% 각 행의 시간을 초 단위(내림)로 맞추어 새로운 변수(TimeRounded) 생성
allData.TimeRounded = dateshift(allData.Time, 'start', 'second');

% [5-1] "Average C.V.(V)" 평균 계산
if ~ismember('Average C.V.(V)', allData.Properties.VariableNames)
    error('allData에 ''Average C.V.(V)'' 변수(컬럼)가 존재하지 않습니다.');
end
T_avgCV = groupsummary(allData, 'TimeRounded', 'mean', 'Average C.V.(V)');
allVars = T_avgCV.Properties.VariableNames;
idx = find(contains(allVars, 'mean_Average'), 1);
if isempty(idx)
    error('그룹요약 결과에서 ''Average C.V.(V)''의 평균 변수명을 찾을 수 없습니다.');
end
cvMeanVar = allVars{idx};

% [5-2] SOC(%) 평균 계산
if ~ismember('SOC(%)', allData.Properties.VariableNames)
    error('allData에 ''SOC(%)'' 변수(컬럼)가 존재하지 않습니다.');
end
T_avgSOC = groupsummary(allData, 'TimeRounded', 'mean', 'SOC(%)');
allVars = T_avgSOC.Properties.VariableNames;
idx_soc = find(contains(allVars, 'mean_SOC'), 1);
if isempty(idx_soc)
    error('그룹요약 결과에서 ''SOC(%)''의 평균 변수명을 찾을 수 없습니다.');
end
socMeanVar = allVars{idx_soc};

%% 6. 플롯 생성
% 전체 기간이 여러 날인 경우, x축은 날짜 단위로 설정할지 여부를 판단합니다.
periodDuration = max(allData.Time) - min(allData.Time);
if periodDuration < days(1)
    % 하루 이하: x축을 시간(시:분:초)로 표시
    xTickFormatStr = 'HH:mm:ss';
else
    % 하루 초과: x축을 날짜와 시간으로 표시
    % (날짜 부분은 'dd-MMM' 또는 'dd-MMM HH:mm' 등으로 표시할 수 있습니다.)
    xTickFormatStr = 'dd-MMM HH:mm:ss';
end

% [6-1] "Average C.V.(V)" 플롯
figure;
plot(T_avgCV.TimeRounded, T_avgCV.(cvMeanVar), 'LineWidth', 1.5);
xlabel('Time');
ylabel('Average C.V.(V)');
title(sprintf('Per-Second Average C.V.(V) (From %s to %s)', weekFolders{1}, weekFolders{end}));
grid on;
% x축 범위를 전체 데이터 범위로 설정
startTime = min(T_avgCV.TimeRounded);
endTime   = max(T_avgCV.TimeRounded);
xlim([startTime, endTime]);
xtickformat(xTickFormatStr);

% [6-2] SOC(%) 플롯
figure;
plot(T_avgSOC.TimeRounded, T_avgSOC.(socMeanVar), 'LineWidth', 1.5);
xlabel('Time');
ylabel('Average SOC (%)');
title(sprintf('Per-Second Average SOC(%%) (From %s to %s)', weekFolders{1}, weekFolders{end}));
grid on;
% x축 범위를 전체 데이터 범위로 설정
startTime = min(T_avgSOC.TimeRounded);
endTime   = max(T_avgSOC.TimeRounded);
xlim([startTime, endTime]);
xtickformat(xTickFormatStr);
