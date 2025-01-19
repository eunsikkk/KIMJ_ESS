%% 1. 기본 설정 및 날짜 폴더 자동 검출
clc; clear; close all;

baseDir    = 'G:\공유 드라이브\BSL_Data2\한전_김제ESS';
kimjFolder = '202106_KIMJ';
basePath   = fullfile(baseDir, kimjFolder);

% 폴더 내의 모든 폴더 목록 가져오기
allItems = dir(basePath);
folderNames = {allItems([allItems.isdir]).name};
% '.'와 '..' 제거
folderNames = folderNames(~ismember(folderNames, {'.', '..'}));

% 날짜 형식의 폴더만 선택 (예: '20210601'은 8자리 숫자)
isDateFolder = cellfun(@(x) ~isempty(regexp(x, '^\d{8}$', 'once')), folderNames);
dateFolders = folderNames(isDateFolder);

% 날짜 폴더들을 오름차순으로 정렬
dateFolders = sort(dateFolders);

%% 2. 원하는 기간(YYYYMMDD) 선택
weekStart = '20210601';
weekEnd   = '20210601';

% 문자열 -> 숫자 변환 후 범위 비교
weekFolders = dateFolders(cellfun(@(x) (str2double(x) >= str2double(weekStart)) && ...
                                       (str2double(x) <= str2double(weekEnd)), dateFolders));

fprintf('선택된 주간 폴더:\n');
disp(weekFolders);

% CSV 파일에서 부가정보(1~4행)를 건너뛰고, 5번째 행을 변수명으로 사용
n_hd = 4;

% 여러 날짜의 파일을 모두 합칠 전체 테이블
allData = table();

%% 3. 선택된 주간 폴더를 순회하며 파일 읽기
for i = 1:length(weekFolders)
    currDate = weekFolders{i};   % 예: '20210601'
    
    % 실제 파일 경로 만들기
    %  → basePath\20210601\20210601_LGCHEM_RARD.csv
    fullFilePath = fullfile(basePath, currDate, ...
        sprintf('%s_LGCHEM_RARD.csv', currDate));

    % 파일이 존재하는지 확인
    if ~exist(fullFilePath, 'file')
        warning('파일이 존재하지 않습니다: %s', fullFilePath);
        continue;
    end

    % readtable로 데이터 읽기
    T = readtable(fullFilePath, 'FileType', 'text', ...
        'NumHeaderLines', n_hd, ...    % 1~4행 건너뛰고, 5번째 행을 변수명
        'ReadVariableNames', true, ...
        'PreserveVariableNames', true);

    % 여러 날짜 데이터를 한 테이블로 합치기
    allData = [allData; T]; %#ok<AGROW>
end

%% 4. 유효 데이터 확인
if isempty(allData)
    error('선택한 기간(%s~%s)에 해당하는 유효 데이터가 없습니다.', weekStart, weekEnd);
end

% (필요하다면) Time 열을 datetime으로 변환
%  → 실제 CSV에 맞게 InputFormat 수정하세요.
try
    allData.Time = datetime(allData.Time, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
catch
    % 포맷이 다를 경우 예외 처리
end

% 'Rack No.' 컬럼에서 중복 없는 랙 번호 목록 얻기
uniqueRacks = unique(allData.("Rack No."));

%% 5. 플롯 모드 선택
fprintf('\n플롯 모드를 선택하세요.\n');
fprintf('1) 셀 번호 입력 → 모든 랙에 대해 해당 셀 전압 플롯\n');
fprintf('2) 랙 번호 입력 → 해당 랙의 모든 셀(1~14) 전압 플롯\n');
plotMode = input('모드 선택 (1 또는 2): ');

switch plotMode
    case 1
        %% 5-1. 셀 번호 기반: 1~14 중 하나 입력 → 모든 랙 플롯
        cellNumber = input('플롯할 셀 번호를 입력하세요 (1 ~ 14): ');
        if cellNumber < 1 || cellNumber > 14
            error('셀 번호는 1에서 14 사이여야 합니다.');
        end
        
        % 예: 1 → '01' / 14 → '14' 로 만들기
        cellStr = sprintf('%02d', cellNumber);
        varName = ['Cell#' cellStr '(V)'];
        fprintf('선택된 변수명: %s\n', varName);

        % 각 랙 번호별로 필터링하여 플롯
        for k = 1:length(uniqueRacks)
            rack = uniqueRacks(k);
            idx = (allData.("Rack No.") == rack);
            T_rack = allData(idx, :);

            figure('Name', sprintf('Rack %d - Cell %s', rack, cellStr));
            plot(T_rack.Time, T_rack.(varName), 'LineWidth', 1.5);
            xlabel('Time');
            ylabel(varName);
            title(sprintf('[Rack %d] Time vs %s', rack, varName), 'Interpreter','none');
            grid on;
        end

    case 2
        %% 5-2. 랙 번호 기반: uniqueRacks 중 하나 입력 → 1~14 셀 모두 플롯
        rackNumber = input('플롯할 랙 번호를 입력하세요: ');
        if ~ismember(rackNumber, uniqueRacks)
            error('입력한 랙 번호(%d)가 데이터에 존재하지 않습니다.', rackNumber);
        end
        
        % 해당 랙의 데이터만 추출
        idxRack = (allData.("Rack No.") == rackNumber);
        T_thisRack = allData(idxRack, :);

        % 셀 번호는 1~14라고 가정
        for cellNum = 1:14
            cellStr = sprintf('%02d', cellNum);
            varName = ['Cell#' cellStr '(V)'];

            % 만약 실제 데이터에 'Cell#01(V)' 같은 변수가 없으면 스킵
            if ~ismember(varName, T_thisRack.Properties.VariableNames)
                warning('해당 테이블에 %s 변수가 없습니다. 건너뜁니다.', varName);
                continue;
            end

            figure('Name', sprintf('Rack %d - Cell %02d', rackNumber, cellNum));
            plot(T_thisRack.Time, T_thisRack.(varName), 'LineWidth', 1.5);
            xlabel('Time');
            ylabel(varName);
            title(sprintf('[Rack %d] Time vs %s', rackNumber, varName), 'Interpreter','none');
            grid on;
        end

    otherwise
        error('올바른 모드 번호(1 또는 2)를 입력하세요.');
end
