  function out = getalldata(obj,sensor={'C3','C4'})
      cSumSegments = [0 cumsum([obj.segments.duration])];

      % Reopen .e file.
      h = fopen(obj.fileName,'r','ieee-le');
      
	  %% find id for sensor
      lChIdx = length(sensor);
      sectionIdx = zeros(lChIdx,1);
      chIdx = zeros(lChIdx,1);
      for i = 1:length(sensor)
  	    chIdx(i) = find(strcmp(sensor(i),{obj.chInfo.sensor}),1);
        tmp = find(strcmp(num2str(chIdx(i)-1),{obj.sections.tag}),1);
        sectionIdx(i) = obj.sections(tmp).index;
      end
     
      % Iterate over all requested channels and populate array. 
	  % get all value
      total_d = 0;
      for i = 1:length(obj.segments)
        total_d = total_d + obj.segments(i).duration + 1;
      end
      total_len = (total_d)*obj.segments(1).samplingRate(chIdx(1));
      out = zeros(total_len, lChIdx); 
      segment = 1;
      for i = 1 : lChIdx
        % Get sampling rate for current channel
        mult = obj.segments(segment).scale(chIdx(i));
        curSF = obj.segments(segment).samplingRate(chIdx(i));
        % Find all sections      
        allSectionIdx = obj.allIndexIDs == sectionIdx(i);
        allSections = find(allSectionIdx);
        % Find relevant sections
        sectionLengths = [obj.index(allSections).sectionL]./2;
        cSectionLengths = [0 cumsum(sectionLengths)];
        skipValues = cSumSegments(segment) * curSF;
        firstSectionForSegment = find(cSectionLengths > skipValues, 1) - 1 ;
        lastSectionForSegment = firstSectionForSegment + ...
          find(cSectionLengths > curSF*obj.segments(segment).duration,1) - 2 ;
        if isempty(lastSectionForSegment)
          lastSectionForSegment = length(cSectionLengths);
        end
        offsetSectionLengths = cSectionLengths - cSectionLengths(firstSectionForSegment);
        useSections = allSections ;
        useSectionL = sectionLengths ;
        % First Partial Segment
        curIdx = 1;
        curSec = obj.index(useSections(1));
        fseek(h, curSec.offset,'bof');
        firstOffset = offsetSectionLengths(1);
        lastOffset = useSectionL(1);
        lsec = lastOffset-firstOffset + 1;
        fseek(h, (firstOffset-1) * 2,'cof');
        out(1 : lsec,i) = fread(h, lsec, 'int16') * mult;
        curIdx = curIdx +  lsec;
        if length(useSections) > 1
          % Full Segments
          for j = 2: (length(useSections))
            curSec = obj.index(useSections(j));
            fseek(h, curSec.offset,'bof');

            out(curIdx : (curIdx + useSectionL(j) - 1),i) = ...
              fread(h, useSectionL(j), 'int16') * mult;
            curIdx = curIdx +  useSectionL(j);
          end
          %% Final Partial Segment
          %curSec = obj.index(useSections(end));
          %fseek(h, curSec.offset,'bof');
          %out(curIdx : ,i) = fread(h, length(out)-curIdx + 1, 'int16') * mult;
        end
      end
      
      % Close the .e file.
      fclose(h);
      
    end

