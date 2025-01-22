clc; clear; close all

%% 1. 기본 경로 및 날짜 폴더 설정
baseDir    = 'G:\공유 드라이브\BSL_Data2\한전_김제ESS';
kimjFolder = '202106_KIMJ';
basePath   = fullfile(baseDir, kimjFolder);

allItems    = dir(basePath);
folderNames = {allItems([allItems.isdir]).name};

% 날짜 형식의 폴더만 선택 (예: '20210615' 형식)
isDateFolder = cellfun(@(x) ~isempty(regexp(x, '^\d{8}$', 'once')), folderNames);
dateFolders  = sort(folderNames(isDateFolder));

%% 2. 원하는 기간 선택
weekStart = '20210615';
weekEnd   = '20210616';

weekFolders = dateFolders(cellfun(@(x) (str2double(x) >= str2double(weekStart)) && ...
                                       (str2double(x) <= str2double(weekEnd)), dateFolders));
fprintf('선택된 기간 폴더:\n');
disp(weekFolders);

filePatternTemplate = '%s_LGCHEM_BSC*.csv';
n_hd = 2;

%% 3. 각 날짜 폴더 내 파일 처리 및 데이터 누적
T_group = table();
for i = 1:length(weekFolders) % weekfolders 에 여러날짜가 들어가기 위한 for문
    currDate   = weekFolders{i};
    data_folder = fullfile(baseDir, kimjFolder, currDate);
    filePattern = fullfile(data_folder, sprintf(filePatternTemplate, currDate));
    fileList    = dir(filePattern);
    
    for j = 1:length(fileList) % 이 부분은 BSC 파일이 8시간 주기로 3파일로 나눠져있기 때문에 BSC_0,1,2 를 반복문으로 처리하기 위해 넣었음
        fullPath = fullfile(fileList(j).folder, fileList(j).name);
        
        % 미리보기 데이터 읽기
        previewData = readcell(fullPath, 'Range', 'A1:ZZ5');
        headerLine = string(previewData(4, :));
        onlineCols = find(contains(headerLine, "[Online]"));
        totalCols  = find(contains(headerLine, "[Total]"));
        variableNames = matlab.lang.makeUniqueStrings(matlab.lang.makeValidName(cellstr(string(previewData(5, :)))));
        
        % 전체 데이터 읽기 (헤더 제외)
        fullDataAll = readtable(fullPath, 'FileType', 'text', 'ReadVariableNames', false, 'TextType','char');
        fullData = fullDataAll(n_hd+1:end, :);
        fullData.Properties.VariableNames = variableNames;
        
        % 온라인/Total 데이터 저장 (개별 CSV 저장은 생략)
        % 그룹 데이터로 누적
        T_group = vertcat(T_group, fullData);
    end
end

%% 4. Time 열 datetime 변환
T_group.Time = datetime(T_group.Time, 'InputFormat', 'yyyy-MM-dd HH:mm');

%% 플롯 생성
figure;
plot(T_group.Time, T_group.("AverageSOC___"), '-r');
hold on;
plot(T_group.Time, T_group.("AverageSOC____1"), '--b');
xlabel('Time');
ylabel('Average SOC (%)');
title(sprintf('Time vs Average SOC(%%) for %s ~ %s', weekFolders{1}, weekFolders{end}));
legend('Average SOC online', 'Average SOC total', 'Location', 'best');
grid on;

figure;
plot(T_group.Time, T_group.DCCurrent_A_, '-b');
xlabel('Time');
ylabel('Current');
title(sprintf('Time vs Current for %s ~ %s', weekFolders{1}, weekFolders{end}));
legend('DC Current', 'Location', 'best');
grid on;

figure;
plot(T_group.Time, T_group.("AverageC_V_Sum_V_"), '-r');
hold on;
plot(T_group.Time, T_group.("AverageC_V_Sum_V__1"), '--b');
xlabel('Time');
ylabel('AverageC_V_Sum_V');
title(sprintf('Time vs AverageC_V_Sum_V for %s ~ %s', weekFolders{1}, weekFolders{end}));
legend('AverageC V Sum V', 'AverageC V Sum V total', 'Location', 'best');
grid on;

figure;
plot(T_group.Time, T_group.("AverageC_V__V_"), '-r');
hold on;
plot(T_group.Time, T_group.("AverageC_V__V__1"), '--b');
xlabel('Time');
ylabel('Average cell voltage');
title(sprintf('Time vs Average cell voltage for %s ~ %s', weekFolders{1}, weekFolders{end}));
legend('Average Cell Voltage - Online', 'Average Cell Voltage - total', 'Location', 'best');
grid on;
