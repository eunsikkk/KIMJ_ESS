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

%% 2. 원하는 기간 선택 (예: 20210615 ~ 20210616)
weekStart = '20210615';
weekEnd   = '20210622';

weekFolders = dateFolders(cellfun(@(x) (str2double(x) >= str2double(weekStart)) && ...
                                       (str2double(x) <= str2double(weekEnd)), dateFolders));
fprintf('선택된 기간 폴더:\n');
disp(weekFolders);

filePatternTemplate = '%s_LGCHEM_RBMS*.csv';
n_hd = 11;

%% 3. 여러 날짜 폴더의 모든 파일 데이터를 하나의 테이블(allData)에 누적
allData = table();
for i = 1:length(weekFolders)
    currDate   = weekFolders{i};  
    data_folder = fullfile(baseDir, kimjFolder, currDate);
    filePattern = fullfile(data_folder, sprintf(filePatternTemplate, currDate));
    fileList    = dir(filePattern);
    
    for j = 1:length(fileList)
        fullFilePath = fullfile(fileList(j).folder, fileList(j).name);
        
        T = readtable(fullFilePath, 'FileType', 'text', ...
            'NumHeaderLines', n_hd, 'ReadVariableNames', true, 'PreserveVariableNames', true);
        allData = [allData; T];  
    end
end


%% 5. PLOT

T_avgCV = groupsummary(allData, 'Time', 'mean', 'Average C.V.(V)');
allVars = T_avgCV.Properties.VariableNames;
idx = find(contains(allVars, 'mean_Average'), 1);
cvMeanVar = allVars{idx};

T_avgSOC = groupsummary(allData, 'Time', 'mean', 'SOC(%)');
allVars = T_avgSOC.Properties.VariableNames;
idx_soc = find(contains(allVars, 'mean_SOC'), 1);
socMeanVar = allVars{idx_soc};

figure;
plot(T_avgCV.Time, T_avgCV.(cvMeanVar), 'LineWidth', 1.5);
xlabel('Time');
ylabel('Average C.V.(V)');
title(sprintf('Per-Second Average C.V.(V) (From %s to %s)', weekFolders{1}, weekFolders{end}));
grid on;

figure;
plot(T_avgSOC.Time, T_avgSOC.(socMeanVar), 'LineWidth', 1.5);
xlabel('Time');
ylabel('Average SOC (%)');
title(sprintf('Per-Second Average SOC(%%) (From %s to %s)', weekFolders{1}, weekFolders{end}));
grid on;

