import { Module } from '@nestjs/common';
import { KitchensModule } from '../kitchens/kitchens.module';
import { SearchController } from './search.controller';
import { SearchService } from './search.service';

@Module({
  imports: [KitchensModule], // reuses KitchensService for the discovery candidate set
  controllers: [SearchController],
  providers: [SearchService],
})
export class SearchModule {}
