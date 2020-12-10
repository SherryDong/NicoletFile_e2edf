
     function out = getdataQ(obj, segment, range, chIdx)
      % GETDATAQ  Returns data from Nicolet file. This is a "QUICK" version of getdata,
      % that uses more memory but operates faster on large datasets by reading
      % a single block of data from disk that contains all data of interest.
      %
      %   OUT = GETDATAQ(OBJ, SEGMENT, RANGE, CHIDX) returns data in an nxm array of
      %   doubles where n is the number of datapoints and m is the number
      %   of channels. RANGE is a 1x2 array with the [StartIndex EndIndex]
      %   and CHIDX is a vector of channel indeces.
      %
      % Andrei Barborica, Dec 2015
      %
     
      % Assert range is 1x2 vector
      assert(length(range) == 2, 'Range is [firstIndex lastIndex]');
      assert(length(segment) == 1, 'Segment must be single value.');

      % Get cumulative sum segments.
      cSumSegments = [0 cumsum([obj.segments.duration])];
      
      % Reopen .e file.
      h = fopen(obj.fileName,'r','ieee-le');
      
      % Find sectionID for channels
      lChIdx = length(chIdx);
      sectionIdx = zeros(lChIdx,1);
      for i = 1:lChIdx
        tmp = find(strcmp(num2str(chIdx(i)-1),{obj.sections.tag}),1);
        sectionIdx(i) = obj.sections(tmp).index;
      end
      
      usedIndexEntries = zeros(size([obj.index.offset]));

      % Iterate over all requested channels and populate array. 
      out = zeros(range(2) - range(1) + 1, lChIdx); 
      for i = 1 : lChIdx
        
        % Get sampling rate for current channel
        curSF = obj.segments(segment).samplingRate(chIdx(i));
        mult = obj.segments(segment).scale(chIdx(i));
        
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
        
        firstSection = find(offsetSectionLengths < range(1) ,1,'last');
        lastSection = find(offsetSectionLengths >= range(2),1)-1;
        
        if isempty(lastSection)
          lastSection = length(offsetSectionLengths);
        end
        
        if lastSection > lastSectionForSegment 
          error('Index out of range for current section: %i > %i, on channel: %i', ... 
            range(2), cSectionLengths(lastSectionForSegment+1), chIdx(i));
        end
        
        useSections = allSections(firstSection: lastSection) ;
        useSectionL = sectionLengths(firstSection: lastSection) ;
       
        % First Partial Segment
        usedIndexEntries(useSections(1)) = 1;
        
        if length(useSections) > 1
          % Full Segments
          for j = 2: (length(useSections)-1)
            usedIndexEntries(useSections(j)) = 1;
          end
          
          % Final Partial Segment
          usedIndexEntries(useSections(end)) = 1;
        end
        
      end
      
      % Read a big chunk of the file, containing data of interest.
      ix = find(usedIndexEntries);
      fseek(h, obj.index(ix(1)).offset,'bof');
      dsize =  obj.index(ix(end)).offset - obj.index(ix(1)).offset + obj.index(ix(end)).sectionL;
      tmp = fread(h,dsize/2,'int16').';

      % Close the .e file.
      fclose(h);
      
      baseOffset = obj.index(ix(1)).offset;
      
      % Extract specified channels
      for i = 1 : lChIdx
        
        % Get sampling rate for current channel
        curSF = obj.segments(segment).samplingRate(chIdx(i));
        mult = obj.segments(segment).scale(chIdx(i));
        
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
        
        firstSection = find(offsetSectionLengths < range(1) ,1,'last');
        lastSection = find(offsetSectionLengths >= range(2),1)-1;
        
        if isempty(lastSection)
          lastSection = length(offsetSectionLengths);
        end
        
        if lastSection > lastSectionForSegment 
          error('Index out of range for current section: %i > %i, on channel: %i', ... 
            range(2), cSectionLengths(lastSectionForSegment+1), chIdx(i));
        end
        
        useSections = allSections(firstSection: lastSection) ;
        useSectionL = sectionLengths(firstSection: lastSection) ;
       
        % First Partial Segment
        curIdx = 1;
        curSec = obj.index(useSections(1));
        %fseek(h, curSec.offset,'bof');
        
        firstOffset = range(1) - offsetSectionLengths(firstSection);
        lastOffset = min([range(2) useSectionL(1)]);
        lsec = lastOffset-firstOffset + 1;
        
        out(1 : lsec,i) = tmp( (curSec.offset - baseOffset)/2 + (firstOffset-1) + (1:lsec) ) * mult;
        curIdx = curIdx +  lsec;
        
        if length(useSections) > 1
          % Full Segments
          for j = 2: (length(useSections)-1)
            curSec = obj.index(useSections(j));
            out(curIdx : (curIdx + useSectionL(j) - 1),i) = ...
                tmp( (curSec.offset - baseOffset)/2 + (1:useSectionL(j)) ) * mult;
            curIdx = curIdx +  useSectionL(j);
          end

          % Final Partial Segment
          curSec = obj.index(useSections(end));
          out(curIdx : end,i) = tmp( (curSec.offset - baseOffset)/2 + (1:(length(out)-curIdx + 1)) ) * mult; % length(out) ??????
        end
        
      end
    end
       
